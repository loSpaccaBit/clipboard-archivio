import Foundation

enum AppInfo {
    static let developerName = "Francesco Pio Nocerino"
    static let repositoryURL = URL(string: "https://github.com/lospaccabit/clipboard-archivio")!

    static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    static var versionLabel: String {
        L10n.Settings.version(shortVersion, buildNumber)
    }

    static var copyrightLine: String {
        let year = Calendar.current.component(.year, from: Date())
        return L10n.Settings.copyright(year, developerName)
    }
}