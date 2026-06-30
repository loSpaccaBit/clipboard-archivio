import Foundation

enum ClipboardContextCategory: String, Codable, CaseIterable, Identifiable {
    case text
    case link
    case code
    case screenshot
    case image
    case document
    case file
    case app

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: return L10n.Content.text
        case .link: return L10n.Content.link
        case .code: return L10n.Content.code
        case .screenshot: return L10n.Content.screenshot
        case .image: return L10n.Content.images
        case .document: return L10n.Content.documents
        case .file: return L10n.Content.file
        case .app: return L10n.Content.app
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .screenshot: return "camera.viewfinder"
        case .image: return "photo"
        case .document: return "doc.richtext"
        case .file: return "doc"
        case .app: return "app"
        }
    }
}

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case pinned
    case vault
    case screenshots
    case documents
    case code
    case links

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return L10n.Filter.all
        case .today: return L10n.Filter.today
        case .pinned: return L10n.Filter.pinned
        case .vault: return L10n.Filter.vault
        case .screenshots: return L10n.Filter.screenshots
        case .documents: return L10n.Filter.documents
        case .code: return L10n.Filter.code
        case .links: return L10n.Filter.links
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .today: return "sun.max"
        case .pinned: return "pin"
        case .vault: return "lock.shield"
        case .screenshots: return "camera.viewfinder"
        case .documents: return "doc.richtext"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .links: return "link"
        }
    }
}

struct ContextSection: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let items: [ClipboardItem]
}