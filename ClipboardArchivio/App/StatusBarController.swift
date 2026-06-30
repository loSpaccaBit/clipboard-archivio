import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusBarController: NSObject {
    private let appState: AppState
    private var statusItem: NSStatusItem?
    private var floatingPanel: GlassFloatingPanel?

    var isPanelVisible: Bool {
        floatingPanel?.isPanelVisible ?? false
    }

    var clipboardPanelWindow: NSWindow? {
        guard floatingPanel?.isPanelVisible == true else { return nil }
        return floatingPanel
    }
    private var hotKeyManager: HotKeyManager?
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        super.init()
        setupStatusItem()
        setupHotKey()
        setupClickOutsideMonitor()
        observePrivacyState()
        observeClipboardPolling()
        observeLocalization()
        appState.clipboardMonitor.start(with: appState.historyStore)
        updateClipboardPolling()
    }

    private func historyRootView() -> some View {
        HistoryView()
            .withLocalization(appState.localization)
            .environmentObject(appState)
            .environmentObject(appState.historyStore)
            .environmentObject(appState.privacyManager)
            .environmentObject(appState.vaultManager)
            .environmentObject(appState.stackManager)
            .environmentObject(appState.retentionSettings)
            .environmentObject(appState.localization)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        guard let button = statusItem?.button else { return }
        button.action = #selector(statusBarButtonClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func observePrivacyState() {
        appState.privacyManager.$isPauseActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)
    }

    private func observeClipboardPolling() {
        appState.$isHistoryVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateClipboardPolling() }
            .store(in: &cancellables)

        appState.privacyManager.onPauseStateChanged = { [weak self] isPaused in
            Task { @MainActor in
                if !isPaused {
                    self?.appState.clipboardMonitor.syncChangeCount()
                }
                self?.updateClipboardPolling()
            }
        }
    }

    private func observeLocalization() {
        appState.localization.$revision
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateStatusIcon()
                if self.isPanelVisible {
                    self.closePanel()
                }
            }
            .store(in: &cancellables)
    }

    func closePanelIfVisible() {
        guard isPanelVisible else { return }
        closePanel()
    }

    private func updateClipboardPolling() {
        if appState.privacyManager.isPauseActive {
            appState.clipboardMonitor.setMode(.paused)
        } else if appState.isHistoryVisible {
            appState.clipboardMonitor.setMode(.active)
        } else {
            appState.clipboardMonitor.setMode(.background)
        }
    }

    private func updateStatusIcon() {
        let symbol = appState.privacyManager.isPauseActive ? "eye.slash" : "paperclip"
        let description = appState.privacyManager.isPauseActive
            ? L10n.Menu.pauseActiveStatus
            : L10n.Menu.activeStatus
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        statusItem?.button?.image?.isTemplate = true
    }

    private func setupHotKey() {
        hotKeyManager = HotKeyManager { [weak self] in
            Task { @MainActor in self?.togglePanel() }
        }
    }

    private func setupClickOutsideMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPanelVisible else { return }

                let click = NSEvent.mouseLocation
                if let panel = self.floatingPanel, panel.frame.contains(click) { return }

                self.closePanel()
            }
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePanel()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu(on: sender)
        } else {
            togglePanel()
        }
    }

    private func showContextMenu(on button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L10n.Menu.openArchive, action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(.separator())
        let prefs = NSMenuItem(title: L10n.Menu.preferences, action: #selector(openPreferences), keyEquivalent: ",")
        prefs.keyEquivalentModifierMask = .command
        menu.addItem(prefs)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.Menu.quit, action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func togglePanel() {
        guard let button = statusItem?.button else { return }
        if isPanelVisible {
            closePanel()
        } else {
            openPanel(relativeTo: button)
        }
    }

    private func openPanel(relativeTo button: NSStatusBarButton) {
        appState.historyStore.refreshExpiredItems()
        AssetStorage.shared.restoreThumbnailCacheLimits()

        let panel = GlassFloatingPanel.create(rootView: historyRootView())
        floatingPanel = panel
        panel.toggle(relativeTo: button)
        NSApp.activate(ignoringOtherApps: true)
        appState.isHistoryVisible = true
        updateClipboardPolling()
    }

    private func closePanel() {
        floatingPanel?.hidePanel()
        floatingPanel?.contentViewController = nil
        floatingPanel = nil
        appState.isHistoryVisible = false
        AssetStorage.shared.trimThumbnailCache(aggressive: true)
        updateClipboardPolling()
    }

    @objc private func openPreferences() {
        closePanelIfVisible()
        appState.openPreferences()
    }

    @objc private func quitApp() {
        appState.historyStore.flushPendingSave()
        NSApp.terminate(nil)
    }
}