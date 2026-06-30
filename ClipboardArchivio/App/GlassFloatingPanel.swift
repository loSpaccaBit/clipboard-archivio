import AppKit
import SwiftUI

/// Pannello trasparente necessario affinché `glassEffect` campioni il desktop (NSPopover è opaco).
final class GlassFloatingPanel: NSPanel {
    /// Necessario per TextField e barra di ricerca — senza questo il pannello non riceve tastiera.
    override var canBecomeKey: Bool { true }

    override var canBecomeMain: Bool { false }
    static func makeHostingController<Content: View>(rootView: Content) -> NSHostingController<Content> {
        let hosting = NSHostingController(rootView: rootView)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.view.layer?.isOpaque = false
        hosting.view.layer?.cornerRadius = GlassTheme.panelRadius
        hosting.view.layer?.masksToBounds = true
        return hosting
    }

    static func create<Content: View>(rootView: Content) -> GlassFloatingPanel {
        let panel = GlassFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: GlassTheme.panelWidth, height: GlassTheme.panelHeight),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.configureForLiquidGlass()
        panel.contentViewController = makeHostingController(rootView: rootView)
        return panel
    }

    private func configureForLiquidGlass() {
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        hidesOnDeactivate = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
    }

    func toggle(relativeTo statusButton: NSStatusBarButton) {
        if isPanelVisible {
            hidePanel()
            return
        }
        position(near: statusButton)
        makeKeyAndOrderFront(nil)
    }

    func hidePanel() {
        orderOut(nil)
    }

    var isPanelVisible: Bool {
        isVisible
    }

    private func position(near button: NSStatusBarButton) {
        guard let window = button.window else { return }
        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenRect = window.convertToScreen(buttonFrame)

        let size = NSSize(width: GlassTheme.panelWidth, height: GlassTheme.panelHeight)
        var origin = NSPoint(
            x: screenRect.midX - size.width / 2,
            y: screenRect.minY - size.height - 6
        )

        if let screen = window.screen {
            let visible = screen.visibleFrame
            origin.x = max(visible.minX + 8, min(origin.x, visible.maxX - size.width - 8))
            origin.y = max(visible.minY + 8, origin.y)
        }

        setFrame(NSRect(origin: origin, size: size), display: true)
    }
}