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
    @ViewBuilder
    func liquidGlassShell() -> some View {
        let shape = RoundedRectangle(cornerRadius: GlassTheme.panelRadius, style: .continuous)
        clipShape(shape)
        #if GLASS_SDK_FALLBACK
            .background(.ultraThinMaterial, in: shape)
        #else
            .glassEffect(.regular, in: .rect(cornerRadius: GlassTheme.panelRadius))
        #endif
    }

    @ViewBuilder
    func nativeInsetBackground() -> some View {
        let shape = RoundedRectangle(cornerRadius: GlassTheme.insetRadius, style: .continuous)
        #if GLASS_SDK_FALLBACK
        background(.thinMaterial, in: shape)
        #else
        glassEffect(.clear.interactive(), in: .rect(cornerRadius: GlassTheme.insetRadius))
        #endif
    }
}

struct HeaderIconButton: View {
    let systemImage: String
    var isActive: Bool = false
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private var label: some View {
        #if GLASS_SDK_FALLBACK
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .medium))
            .frame(width: 32, height: 32)
            .contentShape(Circle())
            .background(.ultraThinMaterial, in: Circle())
            .overlay {
                if isActive {
                    Circle().strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1.5)
                }
            }
        #else
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .medium))
            .frame(width: 32, height: 32)
            .contentShape(Circle())
            .glassEffect(
                isActive ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                in: .circle
            )
        #endif
    }
}