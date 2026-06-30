import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var visibleItems: [ClipboardItem] = []
    @Published private(set) var groupedSections: [ContextSection] = []
    @Published var searchQuery = "" {
        didSet {
            guard searchQuery != oldValue else { return }
            refreshListCaches()
        }
    }
    @Published var activeFilter: HistoryFilter = .all {
        didSet {
            guard activeFilter != oldValue else { return }
            refreshListCaches()
        }
    }
    @Published private(set) var lastCopiedItemID: UUID?

    private var copyFeedbackTask: Task<Void, Never>?
    private var saveDebounceTask: Task<Void, Never>?
    private let saveDebounceInterval: Duration = .milliseconds(400)

    private let maxItems = 500
    private let storageURL: URL
    private var encryptedStorageURL: URL { assets.baseURL.appendingPathComponent("history.enc") }
    private let assets = AssetStorage.shared
    private var isRestoringFromClipboard = false
    private weak var privacyManager: PrivacyManager?
    private weak var vaultManager: VaultManager?
    private weak var retentionSettings: RetentionSettings?
    private weak var encryptionSettings: EncryptionSettings?
    private var expiryTimer: Timer?
    private var decryptedCache: [UUID: ClipboardItem] = [:]

    init() {
        storageURL = assets.baseURL.appendingPathComponent("history.json")
        loadFromDisk()
        refreshListCaches()
        startExpiryTimer()
    }

    func configure(
        privacy: PrivacyManager,
        vault: VaultManager,
        retention: RetentionSettings,
        encryption: EncryptionSettings
    ) {
        privacyManager = privacy
        vaultManager = vault
        retentionSettings = retention
        encryptionSettings = encryption

        vault.onLockStateChanged = { [weak self] unlocked in
            if unlocked {
                self?.populateDecryptedCache()
            } else {
                self?.clearDecryptedCache()
            }
            self?.refreshListCaches()
        }

        encryption.onSettingChanged = { [weak self] in
            self?.save(immediate: true)
        }

        refreshListCaches()

        migrateLegacyVaultItems()
        if vault.isUnlocked {
            populateDecryptedCache()
        }
    }

    var hasVaultedItems: Bool { items.contains(where: \.isVaulted) }

    func resolved(_ item: ClipboardItem) -> ClipboardItem {
        decryptedCache[item.id] ?? item
    }

    func add(parsed: ParsedClipboard) {
        guard !isRestoringFromClipboard else { return }
        guard privacyManager?.shouldSaveClipboard != false else { return }

        let source = ActiveAppDetector.current()
        let item: ClipboardItem?
        switch parsed.type {
        case .text:
            item = makeTextItem(parsed.text ?? "", source: source)
        case .image:
            item = makeImageItem(
                data: parsed.imageData,
                uti: parsed.imageUTI,
                fileName: parsed.imageFileName,
                source: source
            )
        case .file:
            if let data = parsed.inlineFileData {
                item = makeInlineFileItem(
                    data: data,
                    uti: parsed.inlineFileUTI,
                    fileName: parsed.inlineFileName,
                    source: source
                )
            } else {
                item = makeFileItem(urls: parsed.fileURLs, source: source)
            }
        }

        guard var item else { return }
        guard !isDuplicate(item) else { return }

        if item.type == .text, let text = item.content, vaultManager?.shouldAutoVault(text: text) == true {
            item = vaultize(item)
        }

        items.insert(item, at: 0)
        trimHistory()
        refreshListCaches()
        save()
    }

    func copyToClipboard(_ item: ClipboardItem) {
        let item = resolved(item)
        isRestoringFromClipboard = true
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text:
            pasteboard.setString(item.content ?? "", forType: .string)
        case .image:
            if let path = item.assetPath, let url = assets.url(for: path), let data = try? Data(contentsOf: url) {
                if let uti = item.uti, let pbType = ClipboardMediaTypes.pasteboardType(forUTI: uti) {
                    pasteboard.setData(data, forType: pbType)
                } else {
                    pasteboard.setData(data, forType: .png)
                }
                if let image = NSImage(data: data) {
                    pasteboard.writeObjects([image])
                }
            }
        case .file:
            restoreFilesToPasteboard(item, pasteboard: pasteboard)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isRestoringFromClipboard = false
        }

        showCopyFeedback(for: item.id)
    }

    private func showCopyFeedback(for id: UUID) {
        copyFeedbackTask?.cancel()
        lastCopiedItemID = id
        copyFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.95))
            guard !Task.isCancelled, lastCopiedItemID == id else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                lastCopiedItemID = nil
            }
        }
    }

    func copyStackJoined(_ items: [ClipboardItem]) {
        let texts = items.compactMap { item -> String? in
            let item = resolved(item)
            guard item.type == .text else { return item.preview }
            return item.content
        }
        guard !texts.isEmpty else { return }
        isRestoringFromClipboard = true
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(texts.joined(separator: "\n\n"), forType: .string)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isRestoringFromClipboard = false
        }
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()

        if items[index].type == .file {
            if items[index].isPinned {
                items[index] = assets.materializeFileCopy(for: items[index])
            } else if !items[index].isVaulted {
                items[index] = assets.releaseMaterializedCopy(for: items[index])
            }
        }

        refreshListCaches()
        save()
    }

    func moveToVault(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = vaultize(items[index])
        refreshListCaches()
        save()
    }

    func removeFromVault(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = items[index]
        if updated.isEncryptedAtRest {
            if let plain = decryptVaultItemToPlain(updated) {
                updated = plain
            }
        }
        updated.isVaulted = false
        updated.vaultExpiresAt = nil
        updated.encryptedPayloadPath = nil
        if updated.type == .file, !updated.isPinned {
            updated = assets.releaseMaterializedCopy(for: updated)
        }
        items[index] = updated
        decryptedCache.removeValue(forKey: item.id)
        refreshListCaches()
        save()
    }

    func delete(_ item: ClipboardItem) {
        assets.deleteAssets(for: item)
        items.removeAll { $0.id == item.id }
        refreshListCaches()
        save()
    }

    func clearUnpinned() {
        let removed = items.filter { !$0.isPinned && !$0.isVaulted }
        removed.forEach { assets.deleteAssets(for: $0) }
        items.removeAll { !$0.isPinned && !$0.isVaulted }
        refreshListCaches()
        save(immediate: true)
    }

    func clearAll() {
        items.forEach { assets.deleteAssets(for: $0) }
        items.removeAll()
        refreshListCaches()
        save(immediate: true)
    }

    func flushPendingSave() {
        save(immediate: true)
    }

    func thumbnail(for item: ClipboardItem) -> NSImage? {
        guard !item.isVaulted || vaultManager?.isUnlocked == true else { return nil }
        return assets.loadThumbnail(for: resolved(item))
    }

    // MARK: - Private

    private func vaultize(_ item: ClipboardItem) -> ClipboardItem {
        var source = item
        if source.type == .file {
            source = assets.materializeFileCopy(for: source)
        }

        let minutes = vaultManager?.autoExpireMinutes ?? 30
        let vaulted = ClipboardItem(
            id: source.id,
            type: source.type,
            content: source.content,
            fileName: source.fileName,
            fileSize: source.fileSize,
            assetPath: source.assetPath,
            thumbnailPath: source.thumbnailPath,
            uti: source.uti,
            sourceAppName: source.sourceAppName,
            sourceBundleId: source.sourceBundleId,
            contextCategory: source.contextCategory,
            createdAt: source.createdAt,
            isPinned: source.isPinned,
            isVaulted: true,
            vaultExpiresAt: Date().addingTimeInterval(TimeInterval(minutes * 60))
        )
        return encryptVaultItem(vaulted) ?? vaulted
    }

    private func makeTextItem(_ text: String, source: (name: String?, bundleId: String?)) -> ClipboardItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return ClipboardItem(type: .text, content: trimmed, sourceAppName: source.name, sourceBundleId: source.bundleId)
    }

    private func makeImageItem(
        data: Data?,
        uti: String?,
        fileName: String?,
        source: (name: String?, bundleId: String?)
    ) -> ClipboardItem? {
        guard let data else { return nil }
        let id = UUID()
        let resolvedUTI = uti ?? UTType.png.identifier
        let isScreenshot = source.bundleId == "com.apple.screencaptureui"
        let resolvedName: String
        if isScreenshot {
            resolvedName = L10n.Content.screenshotFile
        } else if let fileName, !fileName.isEmpty {
            resolvedName = fileName
        } else {
            resolvedName = ClipboardMediaTypes.defaultFileName(forUTI: resolvedUTI, fallback: L10n.Content.imageFile)
        }
        guard let assetPath = assets.saveImageData(data, id: id, uti: resolvedUTI, fileName: resolvedName) else { return nil }
        let thumbnailPath = NSImage(data: data).flatMap { assets.saveThumbnail($0, id: id) }
        return ClipboardItem(
            id: id,
            type: .image,
            fileName: resolvedName,
            fileSize: Int64(data.count),
            assetPath: assetPath,
            thumbnailPath: thumbnailPath,
            uti: resolvedUTI,
            sourceAppName: source.name,
            sourceBundleId: source.bundleId,
            contextCategory: isScreenshot ? .screenshot : .image
        )
    }

    private func makeInlineFileItem(
        data: Data,
        uti: String?,
        fileName: String?,
        source: (name: String?, bundleId: String?)
    ) -> ClipboardItem? {
        let id = UUID()
        let resolvedUTI = uti ?? UTType.data.identifier
        let resolvedName = fileName ?? ClipboardMediaTypes.defaultFileName(forUTI: resolvedUTI, fallback: L10n.Content.file)
        let isPDF = resolvedUTI == UTType.pdf.identifier || resolvedName.lowercased().hasSuffix(".pdf")

        if isPDF, let saved = assets.savePDFData(data, id: id, fileName: resolvedName) {
            return ClipboardItem(
                id: id,
                type: .file,
                fileName: resolvedName,
                fileSize: saved.size,
                assetPath: saved.assetPath,
                thumbnailPath: saved.thumbnailPath,
                uti: UTType.pdf.identifier,
                sourceAppName: source.name,
                sourceBundleId: source.bundleId,
                contextCategory: .document
            )
        }

        guard let saved = assets.saveFileData(data, id: id, fileName: resolvedName) else { return nil }
        let category: ClipboardContextCategory = ClipboardMediaTypes.isDocument(fileName: resolvedName, uti: resolvedUTI)
            ? .document : .file
        return ClipboardItem(
            id: id,
            type: .file,
            fileName: resolvedName,
            fileSize: saved.size,
            assetPath: saved.assetPath,
            thumbnailPath: saved.thumbnailPath,
            uti: resolvedUTI,
            sourceAppName: source.name,
            sourceBundleId: source.bundleId,
            contextCategory: category
        )
    }

    private func makeFileItem(urls: [URL], source: (name: String?, bundleId: String?)) -> ClipboardItem? {
        guard let primary = urls.first else { return nil }
        let id = UUID()

        let values = try? primary.resourceValues(forKeys: [.fileSizeKey, .typeIdentifierKey])
        let fileSize = Int64(values?.fileSize ?? 0)

        var item = ClipboardItem(
            id: id,
            type: .file,
            content: primary.path,
            fileName: urls.count > 1 ? "\(primary.lastPathComponent) +\(urls.count - 1)" : primary.lastPathComponent,
            fileSize: fileSize,
            assetPath: nil,
            uti: values?.typeIdentifier,
            sourceAppName: source.name,
            sourceBundleId: source.bundleId
        )

        if let thumbnailPath = assets.generateThumbnail(for: item) {
            item = ClipboardItem(
                id: item.id,
                type: item.type,
                content: item.content,
                fileName: item.fileName,
                fileSize: item.fileSize,
                assetPath: item.assetPath,
                thumbnailPath: thumbnailPath,
                uti: item.uti,
                sourceAppName: item.sourceAppName,
                sourceBundleId: item.sourceBundleId,
                contextCategory: item.contextCategory,
                createdAt: item.createdAt,
                isPinned: item.isPinned,
                isVaulted: item.isVaulted,
                vaultExpiresAt: item.vaultExpiresAt
            )
        }
        return item
    }

    private func restoreFilesToPasteboard(_ item: ClipboardItem, pasteboard: NSPasteboard) {
        if let assetPath = item.assetPath, let url = assets.url(for: assetPath), FileManager.default.fileExists(atPath: url.path) {
            pasteboard.writeObjects([url as NSURL])
            if let data = try? Data(contentsOf: url), let uti = item.uti,
               let pbType = ClipboardMediaTypes.pasteboardType(forUTI: uti) {
                pasteboard.setData(data, forType: pbType)
            }
            return
        }
        if let path = item.content {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                pasteboard.writeObjects([url as NSURL])
            }
        }
    }

    private func isDuplicate(_ item: ClipboardItem) -> Bool {
        guard let latest = items.first else { return false }
        guard latest.type == item.type else { return false }
        switch item.type {
        case .text: return latest.content == item.content
        case .image: return latest.fileSize == item.fileSize
        case .file: return latest.fileName == item.fileName && latest.content == item.content
        }
    }

    private func trimHistory() {
        let pinned = items.filter(\.isPinned)
        let vaulted = items.filter { $0.isVaulted && !$0.isPinned }
        var unpinned = items.filter { !$0.isPinned && !$0.isVaulted }
        if unpinned.count > maxItems {
            let removed = Array(unpinned.suffix(from: maxItems))
            removed.forEach { assets.deleteAssets(for: $0) }
            unpinned = Array(unpinned.prefix(maxItems))
        }
        items = pinned + vaulted + unpinned
    }

    private func purgeExpiredVaultItems() {
        let expired = items.filter { $0.isVaulted && ($0.vaultExpiresAt.map { Date() >= $0 } ?? false) }
        guard !expired.isEmpty else { return }
        expired.forEach { assets.deleteAssets(for: $0) }
        items.removeAll { item in expired.contains(where: { $0.id == item.id }) }
        refreshListCaches()
        save()
    }

    func refreshExpiredItems() {
        purgeExpiredVaultItems()
        purgeExpiredByRetention()
    }

    var retentionSummary: String {
        guard let settings = retentionSettings, settings.isEnabled, settings.autoDeleteDays > 0 else {
            return L10n.Retention.autoDeleteOff
        }
        return L10n.Retention.deleteAfter(settings.label)
    }

    private func startExpiryTimer() {
        refreshExpiredItems()
        let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshExpiredItems()
            }
        }
        timer.tolerance = 15
        expiryTimer = timer
    }

    private func purgeExpiredByRetention() {
        guard let cutoff = retentionSettings?.cutoffDate() else { return }
        let expired = items.filter {
            !$0.isPinned && !$0.isVaulted && $0.createdAt < cutoff
        }
        guard !expired.isEmpty else { return }
        expired.forEach { assets.deleteAssets(for: $0) }
        items.removeAll { item in expired.contains(where: { $0.id == item.id }) }
        refreshListCaches()
        save()
    }

    // MARK: - List caches

    func refreshListCaches() {
        let computed = computeVisibleItems()
        visibleItems = computed
        groupedSections = computeGroupedSections(from: computed)
    }

    private func computeVisibleItems() -> [ClipboardItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var result = items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.createdAt > rhs.createdAt
        }

        switch activeFilter {
        case .all:
            break
        case .today:
            result = result.filter { Calendar.current.isDateInToday($0.createdAt) }
        case .pinned:
            result = result.filter(\.isPinned)
        case .vault:
            result = result.filter(\.isVaulted)
        case .screenshots:
            result = result.filter { $0.contextCategory == .screenshot }
        case .documents:
            result = result.filter { $0.contextCategory == .document || $0.isPDF }
        case .code:
            result = result.filter { $0.contextCategory == .code }
        case .links:
            result = result.filter { $0.contextCategory == .link }
        }

        if !query.isEmpty {
            result = result.filter { $0.searchText.contains(query) }
        }
        return result
    }

    private func computeGroupedSections(from items: [ClipboardItem]) -> [ContextSection] {
        guard !items.isEmpty else { return [] }

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if activeFilter != .all || !trimmedQuery.isEmpty {
            let title = trimmedQuery.isEmpty ? activeFilter.label : L10n.Section.results
            let icon = trimmedQuery.isEmpty ? activeFilter.systemImage : "magnifyingglass"
            return [ContextSection(id: "results", title: title, systemImage: icon, items: items)]
        }

        var keyOrder: [String] = []
        var groups: [String: [ClipboardItem]] = [:]
        for item in items {
            let key = ContextClassifier.sectionKey(for: item)
            if groups[key] == nil {
                keyOrder.append(key)
                groups[key] = []
            }
            groups[key]?.append(item)
        }

        keyOrder.sort { lhs, rhs in
            let lp = sectionSortPriority(lhs)
            let rp = sectionSortPriority(rhs)
            if lp != rp { return lp < rp }
            return ContextClassifier.localizedSectionTitle(for: lhs)
                .localizedCaseInsensitiveCompare(ContextClassifier.localizedSectionTitle(for: rhs)) == .orderedAscending
        }

        return keyOrder.compactMap { key in
            guard let sectionItems = groups[key], let sample = sectionItems.first else { return nil }
            return ContextSection(
                id: key,
                title: ContextClassifier.localizedSectionTitle(for: key),
                systemImage: ContextClassifier.sectionIcon(for: sample),
                items: sectionItems
            )
        }
    }

    private func sectionSortPriority(_ key: String) -> Int {
        switch key {
        case "pinned": return 0
        case "vault": return 1
        case "today": return 2
        case "yesterday": return 3
        default:
            if key.hasPrefix("app:") { return 4 }
            return 5
        }
    }

    // MARK: - Encryption

    private func encryptVaultItem(_ item: ClipboardItem) -> ClipboardItem? {
        do {
            let key = try SecureKeychain.shared.ensureVaultKey()
            let payload = VaultPayload(
                content: item.content,
                fileName: item.fileName,
                fileSize: item.fileSize,
                uti: item.uti,
                assetData: assets.assetData(for: item),
                thumbnailData: assets.thumbnailData(for: item)
            )
            let encrypted = try SecureVaultCrypto.encrypt(payload, key: key)
            guard let payloadPath = assets.writeSecurePayload(encrypted, id: item.id) else { return nil }

            assets.deletePlaintextAssets(for: item)

            return ClipboardItem(
                id: item.id,
                type: item.type,
                content: nil,
                fileName: nil,
                fileSize: item.fileSize,
                assetPath: nil,
                thumbnailPath: nil,
                uti: item.uti,
                sourceAppName: item.sourceAppName,
                sourceBundleId: item.sourceBundleId,
                contextCategory: item.contextCategory,
                createdAt: item.createdAt,
                isPinned: item.isPinned,
                isVaulted: true,
                vaultExpiresAt: item.vaultExpiresAt,
                encryptedPayloadPath: payloadPath
            )
        } catch {
            return nil
        }
    }

    private func decryptVaultItemToPlain(_ item: ClipboardItem) -> ClipboardItem? {
        guard let payloadPath = item.encryptedPayloadPath,
              let data = assets.readSecurePayload(relativePath: payloadPath) else { return nil }
        do {
            let key = try SecureKeychain.shared.vaultKey()
            let payload = try SecureVaultCrypto.decrypt(data, key: key)
            assets.deleteSecurePayload(relativePath: payloadPath)
            return restorePlainItem(from: payload, base: item, encryptedPayloadPath: nil)
        } catch {
            return nil
        }
    }

    private func restorePlainItem(
        from payload: VaultPayload,
        base: ClipboardItem,
        encryptedPayloadPath: String?
    ) -> ClipboardItem? {
        var assetPath: String?
        var thumbnailPath: String?

        if let assetData = payload.assetData {
            switch base.type {
            case .image:
                assetPath = assets.saveImageData(assetData, id: base.id, uti: payload.uti, fileName: payload.fileName)
                thumbnailPath = NSImage(data: assetData).flatMap { assets.saveThumbnail($0, id: base.id) }
            case .file:
                let name = payload.fileName ?? "file"
                let isPDF = payload.uti == UTType.pdf.identifier || name.lowercased().hasSuffix(".pdf")
                if isPDF, let saved = assets.savePDFData(assetData, id: base.id, fileName: name) {
                    assetPath = saved.assetPath
                    thumbnailPath = saved.thumbnailPath
                } else if let saved = assets.saveFileData(assetData, id: base.id, fileName: name) {
                    assetPath = saved.assetPath
                    thumbnailPath = saved.thumbnailPath
                }
            case .text:
                break
            }
        }

        return ClipboardItem(
            id: base.id,
            type: base.type,
            content: payload.content,
            fileName: payload.fileName,
            fileSize: payload.fileSize,
            assetPath: assetPath,
            thumbnailPath: thumbnailPath,
            uti: payload.uti ?? base.uti,
            sourceAppName: base.sourceAppName,
            sourceBundleId: base.sourceBundleId,
            contextCategory: base.contextCategory,
            createdAt: base.createdAt,
            isPinned: base.isPinned,
            isVaulted: base.isVaulted,
            vaultExpiresAt: base.vaultExpiresAt,
            encryptedPayloadPath: encryptedPayloadPath
        )
    }

    private func populateDecryptedCache() {
        decryptedCache.removeAll()
        do {
            let key = try SecureKeychain.shared.vaultKey()
            for item in items where item.isEncryptedAtRest {
                guard let path = item.encryptedPayloadPath,
                      let data = assets.readSecurePayload(relativePath: path),
                      let payload = try? SecureVaultCrypto.decrypt(data, key: key),
                      let restored = restorePlainItem(from: payload, base: item, encryptedPayloadPath: path) else {
                    continue
                }
                decryptedCache[item.id] = restored
            }
            refreshListCaches()
        } catch {}
    }

    private func clearDecryptedCache() {
        for (_, cached) in decryptedCache {
            assets.deletePlaintextAssets(for: cached)
        }
        decryptedCache.removeAll()
        refreshListCaches()
    }

    private func migrateLegacyVaultItems() {
        var changed = false
        for index in items.indices where items[index].isVaulted && items[index].encryptedPayloadPath == nil {
            if let encrypted = encryptVaultItem(items[index]) {
                items[index] = encrypted
                changed = true
            }
        }
        if changed { save() }
    }

    private func persistedItems() -> [ClipboardItem] {
        items.map { item in
            guard item.isEncryptedAtRest else { return item }
            return ClipboardItem(
                id: item.id,
                type: item.type,
                content: nil,
                fileName: nil,
                fileSize: item.fileSize,
                assetPath: nil,
                thumbnailPath: nil,
                uti: item.uti,
                sourceAppName: item.sourceAppName,
                sourceBundleId: item.sourceBundleId,
                contextCategory: item.contextCategory,
                createdAt: item.createdAt,
                isPinned: item.isPinned,
                isVaulted: item.isVaulted,
                vaultExpiresAt: item.vaultExpiresAt,
                encryptedPayloadPath: item.encryptedPayloadPath
            )
        }
    }

    private func loadFromDisk() {
        if UserDefaults.standard.bool(forKey: "encryption.fullArchive"),
           FileManager.default.fileExists(atPath: encryptedStorageURL.path) {
            loadEncryptedArchive()
        } else {
            loadPlainArchive()
        }
    }

    private func loadPlainArchive() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            items = try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            items = []
        }
    }

    private func loadEncryptedArchive() {
        guard FileManager.default.fileExists(atPath: encryptedStorageURL.path) else {
            loadPlainArchive()
            return
        }
        do {
            let data = try Data(contentsOf: encryptedStorageURL)
            let key = try SecureKeychain.shared.archiveKey()
            items = try SecureVaultCrypto.decryptArchive(data, key: key)
        } catch {
            items = []
        }
    }

    private func save(immediate: Bool = false) {
        if immediate {
            saveDebounceTask?.cancel()
            saveDebounceTask = nil
            performSave()
            return
        }

        saveDebounceTask?.cancel()
        saveDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: saveDebounceInterval)
            guard !Task.isCancelled else { return }
            performSave()
        }
    }

    private func performSave() {
        let snapshot = persistedItems()
        let encrypt = encryptionSettings?.encryptFullArchive == true
        HistoryPersistence.write(
            snapshot: snapshot,
            encrypt: encrypt,
            plainURL: storageURL,
            encryptedURL: encryptedStorageURL
        )
    }
}