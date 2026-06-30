import SwiftUI

enum GlassTheme {
    static let panelRadius: CGFloat = 22
    static let cardRadius: CGFloat = 10
    static let rowInset: CGFloat = 4
    static let insetRadius: CGFloat = 10
    static let panelWidth: CGFloat = 400
    static let panelHeight: CGFloat = 560
    static let thumbnailSize: CGFloat = 44
}

extension View {
    /// Shell Liquid Glass nativo — richiede finestra trasparente (NSPanel).
    func liquidGlassShell() -> some View {
        clipShape(RoundedRectangle(cornerRadius: GlassTheme.panelRadius, style: .continuous))
            .glassEffect(.regular, in: .rect(cornerRadius: GlassTheme.panelRadius))
    }

    func nativeInsetBackground() -> some View {
        glassEffect(.clear.interactive(), in: .rect(cornerRadius: GlassTheme.insetRadius))
    }
}

struct HeaderIconButton: View {
    let systemImage: String
    var isActive: Bool = false
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 32, height: 32)
                .contentShape(Circle())
                .glassEffect(
                    isActive ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                    in: .circle
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}