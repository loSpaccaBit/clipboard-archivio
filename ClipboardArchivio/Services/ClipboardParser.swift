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

        if let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
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

        return nil
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
            if let data = pasteboard.data(forType: entry.pasteboardType), !data.isEmpty {
                return (data, entry.uti.identifier, entry.defaultFileName)
            }
        }

        if let data = pasteboard.data(forType: .fileContents), !data.isEmpty,
           let entry = ClipboardMediaTypes.entry(matching: data) {
            return (data, entry.uti.identifier, entry.defaultFileName)
        }

        if let data = pasteboard.data(forType: .publicData), !data.isEmpty,
           let entry = ClipboardMediaTypes.entry(matching: data) {
            return (data, entry.uti.identifier, entry.defaultFileName)
        }

        return nil
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