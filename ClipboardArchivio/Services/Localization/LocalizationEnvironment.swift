import SwiftUI

private struct LocalizationManagerKey: EnvironmentKey {
    static let defaultValue: LocalizationManager = .shared
}

extension EnvironmentValues {
    var localization: LocalizationManager {
        get { self[LocalizationManagerKey.self] }
        set { self[LocalizationManagerKey.self] = newValue }
    }
}

/// Applies active locale and layout direction (RTL for Arabic, etc.).
struct LocalizationRootModifier: ViewModifier {
    @ObservedObject private var localization: LocalizationManager

    init(localization: LocalizationManager = .shared) {
        self.localization = localization
    }

    func body(content: Content) -> some View {
        content
            .id(localization.revision)
            .environment(\.locale, localization.activeLocale)
            .environment(\.layoutDirection, localization.layoutDirection)
            .environment(\.localization, localization)
    }
}

extension View {
    func withLocalization(_ manager: LocalizationManager = .shared) -> some View {
        modifier(LocalizationRootModifier(localization: manager))
    }
}