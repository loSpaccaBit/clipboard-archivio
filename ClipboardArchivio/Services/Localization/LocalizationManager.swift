import Foundation
import SwiftUI

/// Runtime localization from bundled `strings.master.json` (no .lproj required).
final class LocalizationManager: ObservableObject, @unchecked Sendable {
    static let shared = LocalizationManager()

    private enum Keys {
        static let preferredLanguage = "localization.preferredLanguage"
    }

    @Published private(set) var preferredLanguageCode: String?
    @Published private(set) var revision: UInt = 0

    /// Called after the active locale changes (refresh open UI).
    var onLanguageChanged: (() -> Void)?

    private var stringTable: [String: [String: String]] = [:]

    var preferredLocale: AppLocale {
        guard let code = preferredLanguageCode, let locale = AppLocale.resolve(code: code) else {
            return .system
        }
        return locale
    }

    var activeLocale: Locale {
        Locale(identifier: activeLanguageCode)
    }

    var layoutDirection: LayoutDirection {
        activeLocale.language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }

    var formattingLocale: Locale { activeLocale }

    private var activeLanguageCode: String {
        normalizeLanguageCode(preferredLanguageCode ?? systemLanguageCode())
    }

    private init() {
        preferredLanguageCode = UserDefaults.standard.string(forKey: Keys.preferredLanguage)
        loadStringTable()
    }

    func setPreferredLanguage(code: String?) {
        let normalized = code?.isEmpty == true ? nil : code
        let apply = { [self] in
            guard preferredLanguageCode != normalized else { return }
            preferredLanguageCode = normalized
            if let normalized {
                UserDefaults.standard.set(normalized, forKey: Keys.preferredLanguage)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.preferredLanguage)
            }
            revision &+= 1
            onLanguageChanged?()
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    func localized(_ key: String) -> String {
        guard let row = stringTable[key] else { return key }
        let code = activeLanguageCode
        return row[code] ?? row["en"] ?? key
    }

    private func loadStringTable() {
        guard let url = Bundle.main.url(forResource: "strings.master", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawStrings = object["strings"] as? [String: Any] else {
            return
        }

        var table: [String: [String: String]] = [:]
        table.reserveCapacity(rawStrings.count)

        for (key, value) in rawStrings {
            if let flat = value as? [String: String] {
                table[key] = flat
                continue
            }
            guard let nested = value as? [String: Any],
                  let localizations = nested["localizations"] as? [String: Any] else {
                continue
            }
            var row: [String: String] = [:]
            for (locale, locValue) in localizations {
                if let locDict = locValue as? [String: Any],
                   let unit = locDict["stringUnit"] as? [String: Any],
                   let text = unit["value"] as? String {
                    row[locale] = text
                } else if let text = locValue as? String {
                    row[locale] = text
                }
            }
            if !row.isEmpty {
                table[key] = row
            }
        }

        stringTable = table
    }

    private func normalizeLanguageCode(_ code: String) -> String {
        if let exact = AppLocale.resolve(code: code), !exact.code.isEmpty {
            return exact.code
        }
        if let prefix = AppLocale.catalog.first(where: { !code.isEmpty && code.hasPrefix($0.code) }) {
            return prefix.code
        }
        let locale = Locale(identifier: code)
        if let language = locale.language.languageCode?.identifier,
           let match = AppLocale.catalog.first(where: { $0.code == language }) {
            return match.code
        }
        return "en"
    }

    private func systemLanguageCode() -> String {
        for identifier in Locale.preferredLanguages {
            let normalized = normalizeLanguageCode(identifier)
            if normalized != "en" || identifier.lowercased().hasPrefix("en") {
                return normalized
            }
        }
        return "en"
    }
}