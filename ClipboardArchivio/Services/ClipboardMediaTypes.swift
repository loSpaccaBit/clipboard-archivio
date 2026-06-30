import AppKit
import UniformTypeIdentifiers

/// Registry centralizzato per tipi immagine e documento su pasteboard e storage.
enum ClipboardMediaTypes {
    struct PasteboardEntry {
        let pasteboardType: NSPasteboard.PasteboardType
        let uti: UTType
        let fileExtension: String
        let defaultFileName: String
    }

    static let imageTypes: [PasteboardEntry] = [
        entry(.png, .png, "png", "immagine.png"),
        entry(.jpeg, .jpeg, "jpg", "immagine.jpg"),
        entry(.heic, .heic, "heic", "immagine.heic"),
        entry(.heif, .heif, "heif", "immagine.heif"),
        entry(.gif, .gif, "gif", "immagine.gif"),
        entry(.webP, .webP, "webp", "immagine.webp"),
        entry(.bmp, .bmp, "bmp", "immagine.bmp"),
        entry(.tiff, .tiff, "tiff", "immagine.tiff"),
        entry(.svg, .svg, "svg", "immagine.svg"),
        entry(.ico, .ico, "ico", "immagine.ico"),
        entry(.icns, .icns, "icns", "immagine.icns"),
        entry(.rawImage, .rawImage, "raw", "immagine.raw"),
    ]

    static let documentTypes: [PasteboardEntry] = [
        entry(.pdf, .pdf, "pdf", "documento.pdf"),
        entry(.docx, .docx, "docx", "documento.docx"),
        entry(.xlsx, .xlsx, "xlsx", "foglio.xlsx"),
        entry(.pptx, .pptx, "pptx", "presentazione.pptx"),
        entry(.doc, .doc, "doc", "documento.doc"),
        entry(.xls, .xls, "xls", "foglio.xls"),
        entry(.ppt, .ppt, "ppt", "presentazione.ppt"),
        entry(.pages, .pages, "pages", "documento.pages"),
        entry(.numbers, .numbers, "numbers", "foglio.numbers"),
        entry(.keynote, .keynote, "key", "presentazione.key"),
        // Text-like formats (HTML, RTF, plain text, …) are handled as ClipboardContentType.text — never as inline files.
        entry(.odt, .odt, "odt", "documento.odt"),
        entry(.ods, .ods, "ods", "foglio.ods"),
        entry(.odp, .odp, "odp", "presentazione.odp"),
        entry(.epub, .epub, "epub", "libro.epub"),
    ]

    static let documentExtensions: Set<String> = Set(
        documentTypes.map(\.fileExtension) + ["key", "txt", "md", "html", "xml", "json", "yaml", "yml"]
    )

    static func fileExtension(forUTI uti: String?) -> String? {
        guard let uti, let type = UTType(uti) else { return nil }
        if let ext = type.preferredFilenameExtension { return ext }
        return imageTypes.first(where: { $0.uti == type })?.fileExtension
            ?? documentTypes.first(where: { $0.uti == type })?.fileExtension
    }

    static func pasteboardType(forUTI uti: String?) -> NSPasteboard.PasteboardType? {
        guard let uti else { return nil }
        if let entry = imageTypes.first(where: { $0.uti.identifier == uti }) {
            return entry.pasteboardType
        }
        if let entry = documentTypes.first(where: { $0.uti.identifier == uti }) {
            return entry.pasteboardType
        }
        return NSPasteboard.PasteboardType(uti)
    }

    static func isImageUTI(_ uti: String?) -> Bool {
        guard let uti, let type = UTType(uti) else { return false }
        return type.conforms(to: .image)
    }

    static func isImageFile(at url: URL) -> Bool {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            let ext = url.pathExtension.lowercased()
            return imageTypes.contains { $0.fileExtension == ext }
        }
        return type.conforms(to: .image)
    }

    static func isDocument(fileName: String?, uti: String? = nil) -> Bool {
        if let uti {
            if documentTypes.contains(where: { $0.uti.identifier == uti }) { return true }
            if let type = UTType(uti) {
                if type.conforms(to: .image) { return false }
                if type.conforms(to: .pdf) || type.conforms(to: .spreadsheet) || type.conforms(to: .presentation) {
                    return true
                }
                if type.conforms(to: .plainText) || type.conforms(to: .rtf) {
                    return true
                }
            }
        }
        guard let ext = fileName?.lowercased().split(separator: ".").last.map(String.init) else { return false }
        return documentExtensions.contains(ext)
    }

    static func defaultFileName(forUTI uti: String?, fallback: String) -> String {
        guard let uti else { return fallback }
        if let entry = imageTypes.first(where: { $0.uti.identifier == uti }) { return entry.defaultFileName }
        if let entry = documentTypes.first(where: { $0.uti.identifier == uti }) { return entry.defaultFileName }
        if let ext = fileExtension(forUTI: uti) { return "file.\(ext)" }
        return fallback
    }

    static func entry(matching data: Data) -> PasteboardEntry? {
        guard !data.isEmpty else { return nil }
        if data.starts(with: [0x25, 0x50, 0x44, 0x46]) { // %PDF
            return documentTypes.first { $0.uti == .pdf }
        }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return imageTypes.first { $0.uti == .png }
        }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return imageTypes.first { $0.uti == .jpeg }
        }
        if data.starts(with: [0x47, 0x49, 0x46]) {
            return imageTypes.first { $0.uti == .gif }
        }
        if data.starts(with: [0x50, 0x4B, 0x03, 0x04]) {
            // ZIP container — prova a distinguere Office Open XML
            if let text = String(data: data.prefix(4096), encoding: .utf8) {
                if text.contains("word/") { return documentTypes.first { $0.uti == .docx } }
                if text.contains("xl/") { return documentTypes.first { $0.uti == .xlsx } }
                if text.contains("ppt/") { return documentTypes.first { $0.uti == .pptx } }
            }
        }
        return nil
    }

    static func imageFromFileURL(_ url: URL) -> (data: Data, uti: String, fileName: String)? {
        guard isImageFile(at: url),
              let data = try? Data(contentsOf: url),
              !data.isEmpty else { return nil }
        let resolvedUTI = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.identifier)
            ?? UTType(filenameExtension: url.pathExtension)?.identifier
            ?? UTType.png.identifier
        return (data, resolvedUTI, url.lastPathComponent)
    }

    private static func entry(
        _ pasteboardType: NSPasteboard.PasteboardType,
        _ uti: UTType,
        _ ext: String,
        _ defaultName: String
    ) -> PasteboardEntry {
        PasteboardEntry(pasteboardType: pasteboardType, uti: uti, fileExtension: ext, defaultFileName: defaultName)
    }
}

// MARK: - Pasteboard type aliases

extension NSPasteboard.PasteboardType {
    static let pdf = NSPasteboard.PasteboardType(UTType.pdf.identifier)
    static let png = NSPasteboard.PasteboardType(UTType.png.identifier)
    static let tiff = NSPasteboard.PasteboardType(UTType.tiff.identifier)
    static let jpeg = NSPasteboard.PasteboardType(UTType.jpeg.identifier)
    static let heic = NSPasteboard.PasteboardType(UTType.heic.identifier)
    static let heif = NSPasteboard.PasteboardType(UTType.heif.identifier)
    static let gif = NSPasteboard.PasteboardType(UTType.gif.identifier)
    static let webP = NSPasteboard.PasteboardType(UTType.webP.identifier)
    static let bmp = NSPasteboard.PasteboardType(UTType.bmp.identifier)
    static let svg = NSPasteboard.PasteboardType(UTType.svg.identifier)
    static let ico = NSPasteboard.PasteboardType("com.microsoft.ico")
    static let icns = NSPasteboard.PasteboardType(UTType.icns.identifier)
    static let rawImage = NSPasteboard.PasteboardType(UTType.rawImage.identifier)

    static let docx = NSPasteboard.PasteboardType("org.openxmlformats.wordprocessingml.document")
    static let xlsx = NSPasteboard.PasteboardType("org.openxmlformats.spreadsheetml.sheet")
    static let pptx = NSPasteboard.PasteboardType("org.openxmlformats.presentationml.presentation")
    static let doc = NSPasteboard.PasteboardType("com.microsoft.word.doc")
    static let xls = NSPasteboard.PasteboardType("com.microsoft.excel.xls")
    static let ppt = NSPasteboard.PasteboardType("com.microsoft.powerpoint.ppt")
    static let pages = NSPasteboard.PasteboardType("com.apple.iwork.pages.pages")
    static let numbers = NSPasteboard.PasteboardType("com.apple.iwork.numbers.numbers")
    static let keynote = NSPasteboard.PasteboardType("com.apple.iwork.keynote.key")
    static let rtf = NSPasteboard.PasteboardType(UTType.rtf.identifier)
    static let plainText = NSPasteboard.PasteboardType(UTType.plainText.identifier)
    static let commaSeparatedText = NSPasteboard.PasteboardType(UTType.commaSeparatedText.identifier)
    static let json = NSPasteboard.PasteboardType(UTType.json.identifier)
    static let xml = NSPasteboard.PasteboardType(UTType.xml.identifier)
    static let html = NSPasteboard.PasteboardType(UTType.html.identifier)
    static let markdown = NSPasteboard.PasteboardType(UTType.markdown.identifier)
    static let odt = NSPasteboard.PasteboardType("org.oasis-open.opendocument.text")
    static let ods = NSPasteboard.PasteboardType("org.oasis-open.opendocument.spreadsheet")
    static let odp = NSPasteboard.PasteboardType("org.oasis-open.opendocument.presentation")
    static let epub = NSPasteboard.PasteboardType(UTType.epub.identifier)

    static let fileURL = NSPasteboard.PasteboardType(UTType.fileURL.identifier)
    static let publicData = NSPasteboard.PasteboardType("public.data")
    static let fileContents = NSPasteboard.PasteboardType("NSPasteboardTypeFileContents")
}

// MARK: - UTType aliases for iWork / Office

private extension UTType {
    static let docx = UTType("org.openxmlformats.wordprocessingml.document") ?? .data
    static let xlsx = UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data
    static let pptx = UTType("org.openxmlformats.presentationml.presentation") ?? .data
    static let doc = UTType("com.microsoft.word.doc") ?? .data
    static let xls = UTType("com.microsoft.excel.xls") ?? .data
    static let ppt = UTType("com.microsoft.powerpoint.ppt") ?? .data
    static let pages = UTType("com.apple.iwork.pages.pages") ?? .data
    static let numbers = UTType("com.apple.iwork.numbers.numbers") ?? .data
    static let keynote = UTType("com.apple.iwork.keynote.key") ?? .data
    static let odt = UTType("org.oasis-open.opendocument.text") ?? .data
    static let ods = UTType("org.oasis-open.opendocument.spreadsheet") ?? .data
    static let odp = UTType("org.oasis-open.opendocument.presentation") ?? .data
    static let markdown = UTType("net.daringfireball.markdown") ?? .plainText
}