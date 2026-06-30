import AppKit
import Combine
import SwiftUI

/// Finestra preferenze sopra il pannello, senza attivare l'app (resta menu bar accessory).
@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private weak var appState: AppState?
    private var window: NSPanel?
    private var localizationCancellable: AnyCancellable?
    var onClose: (() -> Void)?

    private static let preferencesWindowLevel = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)

    var isVisible: Bool {
        window?.isVisible == true
    }

    func configure(appState: AppState) {
        self.appState = appState
        localizationCancellable = appState.localization.$revision
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.close()
            }
    }

    func show(relativeTo clipboardPanel: NSWindow?) {
        guard let appState else { return }

        if let window {
            if let clipboardPanel, clipboardPanel.isVisible {
                position(window, centeredOn: clipboardPanel)
            }
            bringToFront(window)
            return
        }

        let hosting = NSHostingController(rootView: settingsRootView(appState: appState))

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.preferencesWindowTitle
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        self.window = window

        if let clipboardPanel, clipboardPanel.isVisible {
            position(window, centeredOn: clipboardPanel)
        } else {
            window.center()
        }

        bringToFront(window)
    }

    private func position(_ window: NSWindow, centeredOn panel: NSWindow) {
        let panelFrame = panel.frame
        let size = window.frame.size
        var origin = NSPoint(
            x: panelFrame.midX - size.width / 2,
            y: panelFrame.midY - size.height / 2
        )

        if let screen = panel.screen {
            let visible = screen.visibleFrame
            origin.x = max(visible.minX + 12, min(origin.x, visible.maxX - size.width - 12))
            origin.y = max(visible.minY + 12, min(origin.y, visible.maxY - size.height - 12))
        }

        window.setFrame(NSRect(origin: origin, size: size), display: false)
    }

    private func bringToFront(_ window: NSPanel) {
        window.level = Self.preferencesWindowLevel
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.orderFrontRegardless()
        // Nessun NSApp.activate — l'app attiva (es. iTerm) resta invariata
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        onClose?()
    }

    private func settingsRootView(appState: AppState) -> some View {
        SettingsView()
            .withLocalization(appState.localization)
            .environmentObject(appState.localization)
            .environmentObject(appState.historyStore)
            .environmentObject(appState.privacyManager)
            .environmentObject(appState.vaultManager)
            .environmentObject(appState.retentionSettings)
            .environmentObject(appState.launchAtLogin)
            .environmentObject(appState.encryptionSettings)
    }

}