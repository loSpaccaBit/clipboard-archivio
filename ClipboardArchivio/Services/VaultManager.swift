import Foundation
import LocalAuthentication

enum VaultAutoMode: String, CaseIterable, Identifiable {
    case intelligent
    case manualOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .intelligent: return L10n.VaultMode.intelligent
        case .manualOnly: return L10n.VaultMode.manualOnly
        }
    }
}

@MainActor
final class VaultManager: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published var autoExpireMinutes: Int {
        didSet { persistSettings() }
    }
    @Published var autoMode: VaultAutoMode {
        didSet { persistSettings() }
    }
    @Published var sensitivity: VaultSensitivity {
        didSet { persistSettings() }
    }
    @Published private(set) var unlockExpiresAt: Date?

    private var unlockTimer: Timer?

    var onLockStateChanged: ((Bool) -> Void)?

    private enum Keys {
        static let autoExpireMinutes = "vault.autoExpireMinutes"
        static let autoMode = "vault.autoMode"
        static let sensitivity = "vault.sensitivity"
    }

    var needsAuthentication: Bool { !isUnlocked }

    init() {
        let defaults = UserDefaults.standard
        autoExpireMinutes = defaults.object(forKey: Keys.autoExpireMinutes) as? Int ?? 30
        if let raw = defaults.string(forKey: Keys.autoMode),
           let mode = VaultAutoMode(rawValue: raw) {
            autoMode = mode
        } else {
            autoMode = .intelligent
        }
        if let raw = defaults.string(forKey: Keys.sensitivity),
           let level = VaultSensitivity(rawValue: raw) {
            sensitivity = level
        } else {
            sensitivity = .balanced
        }
    }

    func shouldAutoVault(text: String) -> Bool {
        guard autoMode == .intelligent else { return false }
        return SensitiveDetector.isSensitive(text: text, sensitivity: sensitivity)
    }

    func persistSettings() {
        let defaults = UserDefaults.standard
        defaults.set(autoExpireMinutes, forKey: Keys.autoExpireMinutes)
        defaults.set(autoMode.rawValue, forKey: Keys.autoMode)
        defaults.set(sensitivity.rawValue, forKey: Keys.sensitivity)
    }

    func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return await authenticateWithPasscode(context: context)
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: L10n.vaultUnlockReason
            )
            if success { markUnlocked() }
            return success
        } catch {
            return await authenticateWithPasscode(context: LAContext())
        }
    }

    func lock() {
        guard isUnlocked else { return }
        isUnlocked = false
        unlockExpiresAt = nil
        unlockTimer?.invalidate()
        unlockTimer = nil
        onLockStateChanged?(false)
    }

    func isExpired(_ item: ClipboardItem) -> Bool {
        guard let expires = item.vaultExpiresAt else { return false }
        return Date() >= expires
    }

    private func authenticateWithPasscode(context: LAContext) async -> Bool {
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: L10n.vaultUnlockReason
            )
            if success { markUnlocked() }
            return success
        } catch {
            return false
        }
    }

    private func markUnlocked() {
        isUnlocked = true
        unlockExpiresAt = Date().addingTimeInterval(300)
        unlockTimer?.invalidate()
        unlockTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }
        onLockStateChanged?(true)
    }
}