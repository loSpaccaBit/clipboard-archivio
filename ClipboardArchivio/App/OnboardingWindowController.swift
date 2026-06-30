import AppKit
import Combine
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private weak var appState: AppState?
    private var window: NSWindow?
    private var localizationCancellable: AnyCancellable?
    var onFinish: (() -> Void)?

    var isVisible: Bool {
        window?.isVisible == true
    }

    func configure(appState: AppState) {
        self.appState = appState
        localizationCancellable = appState.localization.$revision
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshContent()
            }
    }

    func showIfNeeded() {
        guard !OnboardingStore.isCompleted else { return }
        show()
    }

    func show() {
        guard let appState else { return }

        if window == nil {
            let hosting = NSHostingController(rootView: rootView(appState: appState))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = L10n.Onboarding.windowTitle
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.contentViewController = hosting
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        } else {
            refreshContent()
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func refreshContent() {
        guard let appState, let window else { return }
        window.contentViewController = NSHostingController(rootView: rootView(appState: appState))
    }

    private func rootView(appState: AppState) -> some View {
        OnboardingView { [weak self] in
            self?.complete()
        }
        .withLocalization(appState.localization)
        .environmentObject(appState.localization)
    }

    private func complete() {
        OnboardingStore.markCompleted()
        window?.close()
        onFinish?()
    }

    func windowWillClose(_ notification: Notification) {
        if !OnboardingStore.isCompleted {
            OnboardingStore.markCompleted()
            onFinish?()
        }
        window = nil
    }
}