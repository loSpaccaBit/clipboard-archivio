import AppKit
import PDFKit
import UniformTypeIdentifiers

final class AssetStorage {
    static let shared = AssetStorage()

    let baseURL: URL
    let assetsURL: URL
    let thumbnailsURL: URL
    let filesURL: URL
    let secureURL: URL

    private let maxCopiedFileSize: Int64 = 25 * 1024 * 1024
    private let thumbnailCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 120
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseURL = appSupport.appendingPathComponent("ClipboardArchivio", isDirectory: true)
        assetsURL = baseURL.appendingPathComponent("assets", isDirectory: true)
        thumbnailsURL = baseURL.appendingPathComponent("thumbnails", isDirectory: true)
        filesURL = baseURL.appendingPathComponent("files", isDirectory: true)
        secureURL = baseURL.appendingPathComponent("secure", isDirectory: true)
        try? FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: filesURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: secureURL, withIntermediateDirectories: true)
    }

    func securePayloadPath(for id: UUID) -> String {
        "secure/\(id.uuidString).bin"
    }

    @discardableResult
    func writeSecurePayload(_ data: Data, id: UUID) -> String? {
        let relative = securePayloadPath(for: id)
        let url = baseURL.appendingPathComponent(relative)
        do {
            try data.write(to: url, options: .atomic)
            return relative
        } catch {
            return nil
        }
    }

    func readSecurePayload(relativePath: String) -> Data? {
        let url = baseURL.appendingPathComponent(relativePath)
        return try? Data(contentsOf: url)
    }

    func deleteSecurePayload(relativePath: String?) {
        guard let relativePath else { return }
        removeIfExists(relative: relativePath)
    }

    func url(for relativePath: String?) -> URL? {
        guard let relativePath else { return nil }
        return baseURL.appendingPathComponent(relativePath)
    }

    @discardableResult
    func saveImageData(_ data: Data, id: UUID, uti: String? = nil, fileName: String? = nil) -> String? {
        let ext = ClipboardMediaTypes.fileExtension(forUTI: uti)
            ?? (fileName.flatMap { ($0 as NSString).pathExtension }.flatMap { $0.isEmpty ? nil : $0 })
            ?? "png"
        let name: String
        if let fileName, !fileName.isEmpty {
            let base = sanitized(fileName)
            name = (base as NSString).pathExtension.isEmpty ? "\(base).\(ext)" : base
        } else {
            name = "image.\(ext)"
        }
        let relative = "assets/\(id.uuidString)/\(name)"
        let url = baseURL.appendingPathComponent(relative)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return relative
        } catch {
            return nil
        }
    }

    @discardableResult
    func saveThumbnail(_ image: NSImage, id: UUID) -> String? {
        guard let data = pngData(from: image, maxDimension: 160) else { return nil }
        let relative = "thumbnails/\(id.uuidString).png"
        let url = baseURL.appendingPathComponent(relative)
        do {
            try data.write(to: url, options: .atomic)
            storeThumbnail(image, forKey: id.uuidString as NSString)
            return relative
        } catch {
            return nil
        }
    }

    @discardableResult
    func copyFile(from source: URL, id: UUID) -> (assetPath: String, size: Int64)? {
        let values = try? source.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values?.isRegularFile == true else { return nil }
        let size = Int64(values?.fileSize ?? 0)
        guard size <= maxCopiedFileSize else { return nil }

        let name = source.lastPathComponent
        let relative = "files/\(id.uuidString)/\(name)"
        let destination = baseURL.appendingPathComponent(relative)
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            return (relative, size)
        } catch {
            return nil
        }
    }

    @discardableResult
    func saveFileData(_ data: Data, id: UUID, fileName: String) -> (assetPath: String, thumbnailPath: String?, size: Int64)? {
        let safeName = sanitized(fileName.isEmpty ? "file" : fileName)
        let relative = "files/\(id.uuidString)/\(safeName)"
        let url = baseURL.appendingPathComponent(relative)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            let thumbnailPath = generateFileThumbnail(at: url).flatMap { saveThumbnail($0, id: id) }
            return (relative, thumbnailPath, Int64(data.count))
        } catch {
            return nil
        }
    }

    @discardableResult
    func savePDFData(_ data: Data, id: UUID, fileName: String) -> (assetPath: String, thumbnailPath: String?, size: Int64)? {
        let safeName = sanitized(fileName.isEmpty ? "documento.pdf" : fileName)
        let relative = "files/\(id.uuidString)/\(safeName)"
        let url = baseURL.appendingPathComponent(relative)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            let thumbnail = generatePDFThumbnail(at: url).flatMap { saveThumbnail($0, id: id) }
            return (relative, thumbnail, Int64(data.count))
        } catch {
            return nil
        }
    }

    func generateThumbnail(for item: ClipboardItem) -> String? {
        switch item.type {
        case .text:
            return nil
        case .image:
            guard let path = item.assetPath, let url = url(for: path) else { return nil }
            if let image = NSImage(contentsOf: url) {
                return saveThumbnail(image, id: item.id)
            }
            return nil
        case .file:
            if item.isPDF, let path = item.assetPath ?? item.content, let url = resolveFileURL(path: path) {
                if let thumb = generatePDFThumbnail(at: url) {
                    return saveThumbnail(thumb, id: item.id)
                }
            }
            if let path = item.assetPath ?? item.content, let url = resolveFileURL(path: path) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                return saveThumbnail(icon, id: item.id)
            }
            return nil
        }
    }

    func loadThumbnail(for item: ClipboardItem) -> NSImage? {
        let key = item.id.uuidString as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        guard let image = decodeThumbnail(for: item) else { return nil }
        storeThumbnail(image, forKey: key)
        return image
    }

    func invalidateThumbnail(for id: UUID) {
        thumbnailCache.removeObject(forKey: id.uuidString as NSString)
    }

    /// Libera RAM quando il pannello archivio è chiuso.
    func trimThumbnailCache(aggressive: Bool = false) {
        if aggressive {
            thumbnailCache.removeAllObjects()
        } else {
            thumbnailCache.countLimit = min(thumbnailCache.countLimit, 40)
        }
    }

    func restoreThumbnailCacheLimits() {
        thumbnailCache.countLimit = 120
    }

    private func decodeThumbnail(for item: ClipboardItem) -> NSImage? {
        if let thumbnailPath = item.thumbnailPath, let url = url(for: thumbnailPath) {
            return NSImage(contentsOf: url)
        }
        switch item.type {
        case .text:
            return nil
        case .image:
            if let assetPath = item.assetPath, let url = url(for: assetPath) {
                return scaledImage(NSImage(contentsOf: url), maxDimension: 96)
            }
        case .file:
            if let path = item.assetPath ?? item.content, let url = resolveFileURL(path: path) {
                if item.isPDF, let thumb = generatePDFThumbnail(at: url, size: 96) {
                    return thumb
                }
                return scaledImage(NSWorkspace.shared.icon(forFile: url.path), maxDimension: 48)
            }
        }
        return nil
    }

    private func storeThumbnail(_ image: NSImage, forKey key: NSString) {
        let pixels = Int(image.size.width * image.size.height)
        thumbnailCache.setObject(image, forKey: key, cost: max(pixels * 4, 1))
    }

    func resolveFileURL(path: String) -> URL? {
        if path.hasPrefix("/") {
            return FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : url(for: path)
        }
        return url(for: path)
    }

    func deletePlaintextAssets(for item: ClipboardItem) {
        invalidateThumbnail(for: item.id)
        if let assetPath = item.assetPath { removeIfExists(relative: assetPath) }
        if let thumbnailPath = item.thumbnailPath { removeIfExists(relative: thumbnailPath) }
        let filesFolder = filesURL.appendingPathComponent(item.id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: filesFolder)
        let assetsFolder = assetsURL.appendingPathComponent(item.id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: assetsFolder)
    }

    func deleteAssets(for item: ClipboardItem) {
        deletePlaintextAssets(for: item)
        deleteSecurePayload(relativePath: item.encryptedPayloadPath)
    }

    func assetData(for item: ClipboardItem) -> Data? {
        if let path = item.assetPath, let url = url(for: path) {
            return try? Data(contentsOf: url)
        }
        if item.type == .file, let path = item.content, let url = resolveFileURL(path: path) {
            return try? Data(contentsOf: url)
        }
        return nil
    }

    /// Copia su disco locale un file referenziato (pin / vault). File > 25 MB restano solo riferimento.
    func materializeFileCopy(for item: ClipboardItem) -> ClipboardItem {
        guard item.type == .file else { return item }
        if let assetPath = item.assetPath, url(for: assetPath) != nil,
           FileManager.default.fileExists(atPath: baseURL.appendingPathComponent(assetPath).path) {
            return item
        }
        guard let path = item.content, let source = resolveFileURL(path: path),
              FileManager.default.fileExists(atPath: source.path) else {
            return item
        }
        guard let copied = copyFile(from: source, id: item.id) else { return item }

        return ClipboardItem(
            id: item.id,
            type: item.type,
            content: item.content,
            fileName: item.fileName,
            fileSize: copied.size,
            assetPath: copied.assetPath,
            thumbnailPath: item.thumbnailPath,
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

    /// Rimuove la copia locale mantenendo il riferimento al file originale.
    func releaseMaterializedCopy(for item: ClipboardItem) -> ClipboardItem {
        guard item.type == .file, item.assetPath != nil else { return item }

        if let assetPath = item.assetPath { removeIfExists(relative: assetPath) }
        let filesFolder = filesURL.appendingPathComponent(item.id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: filesFolder)

        return ClipboardItem(
            id: item.id,
            type: item.type,
            content: item.content,
            fileName: item.fileName,
            fileSize: item.fileSize,
            assetPath: nil,
            thumbnailPath: item.thumbnailPath,
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

    func thumbnailData(for item: ClipboardItem) -> Data? {
        guard let path = item.thumbnailPath, let url = url(for: path),
              let image = NSImage(contentsOf: url) else { return nil }
        return pngData(from: image, maxDimension: 160)
    }

    private func removeIfExists(relative: String) {
        let url = baseURL.appendingPathComponent(relative)
        try? FileManager.default.removeItem(at: url)
    }

    private func resolveFileURL(path: String?) -> URL? {
        guard let path else { return nil }
        return resolveFileURL(path: path)
    }

    private func generateFileThumbnail(at url: URL) -> NSImage? {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    private func generatePDFThumbnail(at url: URL, size: CGFloat = 160) -> NSImage? {
        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let scale = min(size / bounds.width, size / bounds.height)
        let target = NSSize(width: bounds.width * scale, height: bounds.height * scale)
        return page.thumbnail(of: target, for: .mediaBox)
    }

    private func pngData(from image: NSImage, maxDimension: CGFloat) -> Data? {
        guard let scaled = scaledImage(image, maxDimension: maxDimension),
              let tiff = scaled.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    private func scaledImage(_ image: NSImage?, maxDimension: CGFloat) -> NSImage? {
        guard let image else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1)
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let scaled = NSImage(size: target)
        scaled.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target), from: .zero, operation: .copy, fraction: 1)
        scaled.unlockFocus()
        return scaled
    }

    private func sanitized(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }
}