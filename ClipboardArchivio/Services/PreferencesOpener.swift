import Foundation

enum PreferencesOpener {
    @MainActor
    static func show(using appState: AppState) {
        appState.openPreferences()
    }
}