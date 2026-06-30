import AppKit
import UniformTypeIdentifiers

struct ParsedClipboard {
    let type: ClipboardContentType
    let text: String?
    let imageData: Data?
    let imageUTI: String?
    let imageFileName: String?
    let fileURLs: [URL]
    let inlineFileData: Data?
    let inlineFileUTI: String?
    let inlineFileName: String?
}

enum ClipboardParser {
    private static let htmlPasteboardTypes: [NSPasteboard.PasteboardType] = [
        .html,
        NSPasteboard.PasteboardType("Apple HTML pasteboard type"),
        NSPasteboard.PasteboardType("NSHTMLPboardType"),
    ]

    static func parse(_ pasteboard: NSPasteboard) -> ParsedClipboard? {
        if let files = readFileURLs(from: pasteboard), !files.isEmpty {
            if files.count == 1, let image = ClipboardMediaTypes.imageFromFileURL(files[0]) {
                return ParsedClipboard(
                    type: .image,
                    text: nil,
                    imageData: image.data,
                    imageUTI: image.uti,
                    imageFileName: image.fileName,
                    fileURLs: [],
                    inlineFileData: nil,
                    inlineFileUTI: nil,
                    inlineFileName: nil
                )
            }
            return ParsedClipboard(
                type: .file,
                text: nil,
                imageData: nil,
                imageUTI: nil,
                imageFileName: nil,
                fileURLs: files,
                inlineFileData: nil,
                inlineFileUTI: nil,
                inlineFileName: nil
            )
        }

        // Web and rich-text copies must resolve as plain text before images or inline blobs.
        if let text = readPlainText(from: pasteboard) {
            return ParsedClipboard(
                type: .text,
                text: text,
                imageData: nil,
                imageUTI: nil,
                imageFileName: nil,
                fileURLs: [],
                inlineFileData: nil,
                inlineFileUTI: nil,
                inlineFileName: nil
            )
        }

        if let image = readImageData(from: pasteboard) {
            return ParsedClipboard(
                type: .image,
                text: nil,
                imageData: image.data,
                imageUTI: image.uti,
                imageFileName: image.fileName,
                fileURLs: [],
                inlineFileData: nil,
                inlineFileUTI: nil,
                inlineFileName: nil
            )
        }

        if let inline = readInlineFileData(from: pasteboard) {
            return ParsedClipboard(
                type: .file,
                text: nil,
                imageData: nil,
                imageUTI: nil,
                imageFileName: nil,
                fileURLs: [],
                inlineFileData: inline.data,
                inlineFileUTI: inline.uti,
                inlineFileName: inline.fileName
            )
        }

        return nil
    }

    private static func readPlainText(from pasteboard: NSPasteboard) -> String? {
        // Prefer explicit plain-text flavor (browser copies) over NSString which may contain HTML markup.
        let candidates: [String?] = [
            pasteboard.string(forType: .plainText),
            pasteboard.string(forType: .string).flatMap(normalizeClipboardString),
            plainTextFromHTML(pasteboard),
            plainText(fromRTF: pasteboard),
        ]

        for candidate in candidates {
            if let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                return text
            }
        }
        return nil
    }

    private static func normalizeClipboardString(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard looksLikeHTML(trimmed) else { return trimmed }
        return htmlStringToPlainText(trimmed) ?? stripHTMLTags(trimmed)
    }

    private static func looksLikeHTML(_ text: String) -> Bool {
        let sample = text.prefix(256).lowercased()
        guard sample.contains("<") else { return false }
        return sample.contains("<html")
            || sample.contains("<meta")
            || sample.contains("<span")
            || sample.contains("<p")
            || sample.contains("<div")
            || sample.contains("<!doctype")
            || sample.contains("</")
            || sample.contains("/>")
    }

    private static func plainTextFromHTML(_ pasteboard: NSPasteboard) -> String? {
        for type in htmlPasteboardTypes {
            guard let data = pasteboard.data(forType: type), !data.isEmpty else { continue }
            if let text = htmlDataToPlainText(data) {
                return text
            }
        }
        return nil
    }

    private static func htmlDataToPlainText(_ data: Data) -> String? {
        let encodings: [String.Encoding] = [.utf8, .utf16, .unicode]
        for encoding in encodings {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: encoding.rawValue,
            ]
            if let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
                let text = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { return text }
            }
        }
        if let raw = String(data: data, encoding: .utf8) {
            return htmlStringToPlainText(raw) ?? stripHTMLTags(raw)
        }
        return nil
    }

    private static func htmlStringToPlainText(_ html: String) -> String? {
        guard let data = html.data(using: .utf8) else { return nil }
        return htmlDataToPlainText(data)
    }

    private static func stripHTMLTags(_ html: String) -> String? {
        guard let data = html.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        if let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            let text = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }

        var text = html
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func plainText(fromRTF pasteboard: NSPasteboard) -> String? {
        guard let data = pasteboard.data(forType: .rtf), !data.isEmpty else { return nil }
        guard let attributed = try? NSAttributedString(rtf: data, documentAttributes: nil) else { return nil }
        let text = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func readFileURLs(from pasteboard: NSPasteboard) -> [URL]? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL], !urls.isEmpty {
            return urls
        }
        if let items = pasteboard.pasteboardItems {
            var urls: [URL] = []
            for item in items {
                if let urlString = item.string(forType: .fileURL),
                   let url = URL(string: urlString), url.isFileURL {
                    urls.append(url)
                }
            }
            if !urls.isEmpty { return urls }
        }
        return nil
    }

    private static func readInlineFileData(from pasteboard: NSPasteboard) -> (data: Data, uti: String, fileName: String)? {
        for entry in ClipboardMediaTypes.documentTypes {
            guard let data = pasteboard.data(forType: entry.pasteboardType), !data.isEmpty else { continue }
            if isTextualClipboardData(data) { continue }
            return (data, entry.uti.identifier, entry.defaultFileName)
        }

        if let data = pasteboard.data(forType: .fileContents), !data.isEmpty, !isTextualClipboardData(data),
           let entry = ClipboardMediaTypes.entry(matching: data) {
            return (data, entry.uti.identifier, entry.defaultFileName)
        }

        if let data = pasteboard.data(forType: .publicData), !data.isEmpty, !isTextualClipboardData(data),
           let entry = ClipboardMediaTypes.entry(matching: data) {
            return (data, entry.uti.identifier, entry.defaultFileName)
        }

        return nil
    }

    private static func isTextualClipboardData(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            return false
        }
        return looksLikeHTML(text)
    }

    private static func readImageData(from pasteboard: NSPasteboard) -> (data: Data, uti: String, fileName: String)? {
        for entry in ClipboardMediaTypes.imageTypes {
            if let data = pasteboard.data(forType: entry.pasteboardType), !data.isEmpty {
                return (data, entry.uti.identifier, entry.defaultFileName)
            }
        }

        if let tiff = pasteboard.data(forType: .tiff), !tiff.isEmpty {
            return (tiff, UTType.tiff.identifier, "immagine.tiff")
        }

        if let objects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = objects.first,
           let data = pngData(from: image) {
            return (data, UTType.png.identifier, "immagine.png")
        }

        if let image = NSImage(pasteboard: pasteboard) {
            if let data = nativeData(from: image, pasteboard: pasteboard) {
                return data
            }
            if let data = pngData(from: image) {
                return (data, UTType.png.identifier, "immagine.png")
            }
        }

        return nil
    }

    private static func nativeData(from image: NSImage, pasteboard: NSPasteboard) -> (data: Data, uti: String, fileName: String)? {
        for entry in ClipboardMediaTypes.imageTypes {
            if pasteboard.types?.contains(entry.pasteboardType) == true,
               let data = pasteboard.data(forType: entry.pasteboardType), !data.isEmpty {
                return (data, entry.uti.identifier, entry.defaultFileName)
            }
        }
        if let tiff = image.tiffRepresentation, !tiff.isEmpty {
            return (tiff, UTType.tiff.identifier, "immagine.tiff")
        }
        return nil
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}