import Foundation

enum OnboardingStore {
    private static let completedKey = "onboarding.completed"

    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    #if DEBUG
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: completedKey)
    }
    #endif
}