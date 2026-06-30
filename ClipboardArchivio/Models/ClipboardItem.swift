import Foundation
import UniformTypeIdentifiers

struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let type: ClipboardContentType
    let content: String?
    let fileName: String?
    let fileSize: Int64?
    let assetPath: String?
    let thumbnailPath: String?
    let uti: String?
    let sourceAppName: String?
    let sourceBundleId: String?
    let contextCategory: ClipboardContextCategory
    let createdAt: Date
    var isPinned: Bool
    var isVaulted: Bool
    var vaultExpiresAt: Date?
    /// Percorso relativo del payload AES-GCM (es. secure/uuid.bin).
    var encryptedPayloadPath: String?

    init(
        id: UUID = UUID(),
        type: ClipboardContentType,
        content: String? = nil,
        fileName: String? = nil,
        fileSize: Int64? = nil,
        assetPath: String? = nil,
        thumbnailPath: String? = nil,
        uti: String? = nil,
        sourceAppName: String? = nil,
        sourceBundleId: String? = nil,
        contextCategory: ClipboardContextCategory? = nil,
        createdAt: Date = Date(),
        isPinned: Bool = false,
        isVaulted: Bool = false,
        vaultExpiresAt: Date? = nil,
        encryptedPayloadPath: String? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.fileName = fileName
        self.fileSize = fileSize
        self.assetPath = assetPath
        self.thumbnailPath = thumbnailPath
        self.uti = uti
        self.sourceAppName = sourceAppName
        self.sourceBundleId = sourceBundleId
        self.contextCategory = contextCategory ?? ContextClassifier.classify(
            type: type,
            content: content,
            fileName: fileName,
            sourceBundleId: sourceBundleId,
            sourceAppName: sourceAppName
        )
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.isVaulted = isVaulted
        self.vaultExpiresAt = vaultExpiresAt
        self.encryptedPayloadPath = encryptedPayloadPath
    }

    var isEncryptedAtRest: Bool {
        isVaulted && encryptedPayloadPath != nil
    }

    var preview: String {
        if isVaulted, content == nil, fileName == nil, assetPath == nil {
            return L10n.protectedContent
        }
        switch type {
        case .text:
            let text = (content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let singleLine = text.replacingOccurrences(of: "\n", with: " ")
            if singleLine.count <= 120 { return singleLine.isEmpty ? L10n.Content.emptyText : singleLine }
            return String(singleLine.prefix(117)) + "..."
        case .image:
            if let fileName { return fileName }
            return contextCategory == .screenshot ? L10n.Content.screenshot : L10n.Content.image
        case .file:
            return fileName ?? content ?? L10n.Content.file
        }
    }

    var subtitle: String {
        var parts: [String] = []
        if let app = sourceAppName, !app.isEmpty { parts.append(app) }
        parts.append(contextCategory.label)
        if let fileSize, type != .text {
            parts.append(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
        }
        return parts.joined(separator: " · ")
    }

    var fileExtensionLabel: String {
        guard let fileName else { return type.label }
        let ext = (fileName as NSString).pathExtension.uppercased()
        return ext.isEmpty ? type.label : ext
    }

    var isPDF: Bool {
        if uti == UTType.pdf.identifier { return true }
        if fileName?.lowercased().hasSuffix(".pdf") == true { return true }
        return false
    }

    var isDocument: Bool {
        ClipboardMediaTypes.isDocument(fileName: fileName, uti: uti)
    }

    var documentIconName: String {
        guard type == .file else { return "doc.fill" }
        if isPDF { return "doc.richtext" }
        let ext = (fileName ?? "").lowercased().split(separator: ".").last.map(String.init) ?? ""
        switch ext {
        case "doc", "docx", "odt", "pages", "rtf", "md", "txt":
            return "doc.text"
        case "xls", "xlsx", "ods", "numbers", "csv":
            return "tablecells"
        case "ppt", "pptx", "odp", "key":
            return "rectangle.stack"
        case "html", "xml", "json":
            return "chevron.left.forwardslash.chevron.right"
        case "epub":
            return "book"
        default:
            return "doc.fill"
        }
    }

    var searchText: String {
        if isEncryptedAtRest {
            return [type.label, sourceAppName, contextCategory.label, "vault", "protetto"]
                .compactMap { $0 }
                .joined(separator: " ")
                .lowercased()
        }
        return [content, fileName, type.label, fileExtensionLabel, sourceAppName, contextCategory.label]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
    }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = LocalizationManager.shared.formattingLocale
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    enum CodingKeys: String, CodingKey {
        case id, type, content, fileName, fileSize, assetPath, thumbnailPath, uti
        case sourceAppName, sourceBundleId, contextCategory, createdAt, isPinned, isVaulted, vaultExpiresAt
        case encryptedPayloadPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isVaulted = try container.decodeIfPresent(Bool.self, forKey: .isVaulted) ?? false
        vaultExpiresAt = try container.decodeIfPresent(Date.self, forKey: .vaultExpiresAt)
        encryptedPayloadPath = try container.decodeIfPresent(String.self, forKey: .encryptedPayloadPath)
        type = try container.decodeIfPresent(ClipboardContentType.self, forKey: .type) ?? .text
        content = try container.decodeIfPresent(String.self, forKey: .content)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
        assetPath = try container.decodeIfPresent(String.self, forKey: .assetPath)
        thumbnailPath = try container.decodeIfPresent(String.self, forKey: .thumbnailPath)
        uti = try container.decodeIfPresent(String.self, forKey: .uti)
        sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
        sourceBundleId = try container.decodeIfPresent(String.self, forKey: .sourceBundleId)
        if let category = try container.decodeIfPresent(ClipboardContextCategory.self, forKey: .contextCategory) {
            contextCategory = category
        } else {
            contextCategory = ContextClassifier.classify(
                type: type,
                content: content,
                fileName: fileName,
                sourceBundleId: sourceBundleId,
                sourceAppName: sourceAppName
            )
        }
    }
}