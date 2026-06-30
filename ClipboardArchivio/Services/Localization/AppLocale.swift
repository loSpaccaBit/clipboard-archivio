import Foundation

/// BCP-47 locale supported by the app (enterprise catalog).
struct AppLocale: Identifiable, Hashable, Sendable {
    let code: String
    let nativeName: String
    let englishName: String

    var id: String { code.isEmpty ? "system" : code }

    /// Empty code = follow macOS system language.
    static let system = AppLocale(code: "", nativeName: "", englishName: "")

    static let catalog: [AppLocale] = [
        AppLocale(code: "en", nativeName: "English", englishName: "English"),
        AppLocale(code: "it", nativeName: "Italiano", englishName: "Italian"),
        AppLocale(code: "de", nativeName: "Deutsch", englishName: "German"),
        AppLocale(code: "fr", nativeName: "Français", englishName: "French"),
        AppLocale(code: "es", nativeName: "Español", englishName: "Spanish"),
        AppLocale(code: "pt-BR", nativeName: "Português (Brasil)", englishName: "Portuguese (Brazil)"),
        AppLocale(code: "ja", nativeName: "日本語", englishName: "Japanese"),
        AppLocale(code: "zh-Hans", nativeName: "简体中文", englishName: "Chinese (Simplified)"),
        AppLocale(code: "ko", nativeName: "한국어", englishName: "Korean"),
        AppLocale(code: "nl", nativeName: "Nederlands", englishName: "Dutch"),
        AppLocale(code: "pl", nativeName: "Polski", englishName: "Polish"),
        AppLocale(code: "ru", nativeName: "Русский", englishName: "Russian"),
        AppLocale(code: "ar", nativeName: "العربية", englishName: "Arabic"),
        AppLocale(code: "tr", nativeName: "Türkçe", englishName: "Turkish"),
    ]

    static func resolve(code: String) -> AppLocale? {
        catalog.first { $0.code == code }
    }

    /// Maps catalog code to `.lproj` folder name inside the app bundle.
    var lprojName: String {
        switch code {
        case "pt-BR": return "pt-BR"
        case "zh-Hans": return "zh-Hans"
        default: return code
        }
    }
}