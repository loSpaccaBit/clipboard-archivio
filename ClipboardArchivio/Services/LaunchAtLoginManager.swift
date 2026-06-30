import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var lastError: String?

    private enum Keys {
        /// `nil` = mai configurato (primo avvio → abilita login item).
        static let userPreference = "launchAtLogin.userPreference"
    }

    /// Al primo avvio registra l'app nei Login Items; poi rispetta la scelta dell'utente.
    func applyDefaultIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.userPreference) == nil {
            setEnabled(true)
            defaults.set(true, forKey: Keys.userPreference)
        } else {
            refreshStatus()
        }
    }

    func refreshStatus() {
        guard #available(macOS 13.0, *) else {
            isEnabled = false
            return
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        guard #available(macOS 13.0, *) else {
            lastError = L10n.Settings.launchLoginError
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            UserDefaults.standard.set(enabled, forKey: Keys.userPreference)
            refreshStatus()
        } catch {
            lastError = error.localizedDescription
            refreshStatus()
        }
    }
}