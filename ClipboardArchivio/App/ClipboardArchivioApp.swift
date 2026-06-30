import AppKit
import SwiftUI

@main
struct ClipboardArchivioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .withLocalization(appDelegate.appState.localization)
                .environmentObject(appDelegate.appState.localization)
                .environmentObject(appDelegate.appState.historyStore)
                .environmentObject(appDelegate.appState.privacyManager)
                .environmentObject(appDelegate.appState.vaultManager)
                .environmentObject(appDelegate.appState.retentionSettings)
                .environmentObject(appDelegate.appState.launchAtLogin)
                .environmentObject(appDelegate.appState.encryptionSettings)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private(set) var statusBarController: StatusBarController?
    private let preferencesWindow = PreferencesWindowController()
    private let onboardingWindow = OnboardingWindowController()
    private var localKeyboardMonitor: Any?
    private var globalKeyboardMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if OnboardingStore.isCompleted {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }

        preferencesWindow.configure(appState: appState)

        appState.openPreferencesHandler = { [weak self] in
            self?.showPreferences()
        }

        statusBarController = StatusBarController(appState: appState)

        onboardingWindow.configure(appState: appState)
        onboardingWindow.onFinish = { [weak self] in
            self?.finishFirstLaunchOnboarding()
        }

        appState.historyStore.refreshExpiredItems()
        appState.launchAtLogin.applyDefaultIfNeeded()
        setupKeyboardShortcuts()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.onboardingWindow.showIfNeeded()
        }
    }

    var isClipboardPanelVisible: Bool {
        statusBarController?.isPanelVisible ?? false
    }

    func showPreferences() {
        statusBarController?.closePanelIfVisible()
        preferencesWindow.show(relativeTo: statusBarController?.clipboardPanelWindow)
    }

    private func finishFirstLaunchOnboarding() {
        NSApp.setActivationPolicy(.accessory)
        statusBarController?.openArchivePanel()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.historyStore.flushPendingSave()
    }

    private func setupKeyboardShortcuts() {
        localKeyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.handlePanelShortcut(event) != true else { return nil }
            return event
        }
        globalKeyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handlePanelShortcut(event)
        }
    }

    /// Scorciatoie solo con pannello archivio o preferenze aperti.
    private func handlePanelShortcut(_ event: NSEvent) -> Bool {
        guard isClipboardPanelVisible || preferencesWindow.isVisible else { return false }
        guard event.modifierFlags.contains(.command) else { return false }

        switch event.charactersIgnoringModifiers {
        case ",":
            showPreferences()
            return true
        case "f":
            guard isClipboardPanelVisible else { return false }
            appState.focusSearch()
            return true
        default:
            return false
        }
    }
}