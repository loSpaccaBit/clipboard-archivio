import SwiftUI

struct ItemThumbnailView: View {
    let item: ClipboardItem
    let image: NSImage?

    @ScaledMetric(relativeTo: .body) private var size = GlassTheme.thumbnailSize

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(tintColor)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .frame(width: size, height: size)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
    }

    private var iconName: String {
        switch item.type {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .file: return item.documentIconName
        }
    }

    private var tintColor: Color {
        switch item.contextCategory {
        case .link: return .blue
        case .code: return .purple
        case .screenshot: return .teal
        case .document: return .red
        case .image: return .green
        default: return .secondary
        }
    }
}