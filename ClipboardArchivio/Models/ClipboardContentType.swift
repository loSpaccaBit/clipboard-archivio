import Foundation

enum ClipboardContentType: String, Codable, CaseIterable {
    case text
    case image
    case file

    var label: String {
        switch self {
        case .text: return L10n.Content.text
        case .image: return L10n.Content.image
        case .file: return L10n.Content.file
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
}