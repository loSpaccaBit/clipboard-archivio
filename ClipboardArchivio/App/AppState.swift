import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var isHistoryVisible = false
    @Published private(set) var focusSearchToken = 0
    let historyStore = HistoryStore()
    let clipboardMonitor = ClipboardMonitor()
    let privacyManager = PrivacyManager()
    let vaultManager = VaultManager()
    let stackManager = StackPasteManager()
    let retentionSettings = RetentionSettings()
    let launchAtLogin = LaunchAtLoginManager()
    let encryptionSettings = EncryptionSettings()
    let localization = LocalizationManager.shared

    var openPreferencesHandler: (() -> Void)?

    init() {
        historyStore.configure(
            privacy: privacyManager,
            vault: vaultManager,
            retention: retentionSettings,
            encryption: encryptionSettings
        )
        localization.onLanguageChanged = { [weak self] in
            self?.historyStore.refreshListCaches()
        }
    }

    func openPreferences() {
        openPreferencesHandler?()
    }

    func focusSearch() {
        focusSearchToken += 1
    }
}