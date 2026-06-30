import Foundation

struct RetentionOption: Identifiable, Hashable {
    let days: Int
    let label: String
    var id: Int { days }
}

@MainActor
final class RetentionSettings: ObservableObject {
    static var options: [RetentionOption] {
        [
            RetentionOption(days: 0, label: L10n.Retention.never),
            RetentionOption(days: 7, label: L10n.Retention.days7),
            RetentionOption(days: 14, label: L10n.Retention.days14),
            RetentionOption(days: 30, label: L10n.Retention.days30),
            RetentionOption(days: 60, label: L10n.Retention.days60),
            RetentionOption(days: 90, label: L10n.Retention.days90),
            RetentionOption(days: 180, label: L10n.Retention.months6),
            RetentionOption(days: 365, label: L10n.Retention.year1),
        ]
    }

    @Published var autoDeleteDays: Int {
        didSet { UserDefaults.standard.set(autoDeleteDays, forKey: Keys.autoDeleteDays) }
    }

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }

    var label: String {
        RetentionSettings.options.first { $0.days == autoDeleteDays }?.label ?? L10n.Retention.customDays(autoDeleteDays)
    }

    private enum Keys {
        static let autoDeleteDays = "retention.autoDeleteDays"
        static let isEnabled = "retention.isEnabled"
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.autoDeleteDays) != nil {
            autoDeleteDays = defaults.integer(forKey: Keys.autoDeleteDays)
        } else {
            autoDeleteDays = 30
        }
        isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
    }

    func cutoffDate() -> Date? {
        guard isEnabled, autoDeleteDays > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: -autoDeleteDays, to: Date())
    }
}