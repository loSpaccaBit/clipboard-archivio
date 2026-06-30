import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: HistoryStore
    @EnvironmentObject private var privacy: PrivacyManager
    @EnvironmentObject private var vault: VaultManager
    @EnvironmentObject private var retention: RetentionSettings
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginManager
    @EnvironmentObject private var encryption: EncryptionSettings
    @EnvironmentObject private var localization: LocalizationManager

    @State private var showClearAllConfirm = false

    var body: some View {
        Form {
            generalSection
            historySection
            privacySection
            sensitiveSection
            securitySection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 480)
        .navigationTitle(L10n.appName)
        .onChange(of: retention.autoDeleteDays) { store.refreshExpiredItems() }
        .onChange(of: retention.isEnabled) { store.refreshExpiredItems() }
        .onAppear { launchAtLogin.refreshStatus() }
        .confirmationDialog(
            L10n.Settings.clearAllConfirmTitle,
            isPresented: $showClearAllConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.Settings.clearAll, role: .destructive) { store.clearAll() }
            Button(L10n.Settings.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Settings.clearAllConfirmMessage)
        }
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section {
            Picker(L10n.Settings.appLanguage, selection: languageBinding) {
                Text(L10n.Settings.followSystem).tag("")
                ForEach(AppLocale.catalog) { locale in
                    Text("\(locale.nativeName) — \(locale.englishName)").tag(locale.code)
                }
            }

            Toggle(L10n.Settings.launchAtLogin, isOn: launchAtLoginBinding)
            if let error = launchAtLogin.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            LabeledContent(L10n.Settings.openHistory) {
                Text("⌘⇧V").font(.system(.body, design: .monospaced))
            }
            LabeledContent(L10n.Settings.preferences) {
                Text("⌘,").font(.system(.body, design: .monospaced))
            }
        } header: {
            Text(L10n.Settings.general)
        } footer: {
            Text(L10n.Settings.launchFooter)
        }
    }

    private var historySection: some View {
        Section {
            Toggle(L10n.Settings.autoDelete, isOn: $retention.isEnabled)
            if retention.isEnabled {
                Picker(L10n.Settings.deleteAfter, selection: $retention.autoDeleteDays) {
                    ForEach(RetentionSettings.options) { option in
                        Text(option.label).tag(option.days)
                    }
                }
            }

            Button(L10n.Settings.clearExceptPinnedVault) { store.clearUnpinned() }
            Button(L10n.Settings.clearAll, role: .destructive) { showClearAllConfirm = true }
        } header: {
            Text(L10n.Settings.history)
        } footer: {
            Text(L10n.Settings.retentionFooter)
        }
    }

    private var privacySection: some View {
        Section {
            Picker(L10n.Settings.defaultPauseDuration, selection: $privacy.pauseDurationMinutes) {
                Text(L10n.minutes(5)).tag(5)
                Text(L10n.minutes(10)).tag(10)
                Text(L10n.minutes(30)).tag(30)
                Text(L10n.minutes(60)).tag(60)
            }

            if privacy.isPauseActive, let remaining = privacy.pauseRemainingText {
                LabeledContent(L10n.pauseActive) {
                    Text(remaining).foregroundStyle(.orange)
                }
                Button(L10n.resumeSaving) { privacy.cancelPause() }
            }
        } header: {
            Text(L10n.Settings.privacyTitle)
        } footer: {
            Text(L10n.Settings.privacyFooter)
        }
    }

    private var sensitiveSection: some View {
        Section {
            Toggle(L10n.Settings.vaultAutoProtect, isOn: vaultAutoProtectBinding)

            Picker(L10n.vaultAutoDelete, selection: $vault.autoExpireMinutes) {
                Text(L10n.minutes(15)).tag(15)
                Text(L10n.minutes(30)).tag(30)
                Text(L10n.oneHour()).tag(60)
                Text(L10n.hours24()).tag(1440)
            }
        } header: {
            Text(L10n.Settings.sensitiveContent)
        } footer: {
            Text(L10n.Settings.vaultSimpleFooter)
        }
    }

    private var securitySection: some View {
        Section {
            Toggle(L10n.Settings.encryptArchive, isOn: $encryption.encryptFullArchive)
        } header: {
            Text(L10n.Settings.security)
        } footer: {
            Text(L10n.Settings.securitySimpleFooter)
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent(L10n.Settings.developer) {
                Text(AppInfo.developerName)
                    .foregroundStyle(.secondary)
            }
            LabeledContent(L10n.Settings.versionTitle) {
                Text(AppInfo.versionLabel)
                    .foregroundStyle(.secondary)
            }
            Text(AppInfo.copyrightLine)
                .font(.caption)
                .foregroundStyle(.tertiary)
        } header: {
            Text(L10n.Settings.about)
        }
    }

    // MARK: - Bindings

    private var languageBinding: Binding<String> {
        Binding(
            get: { localization.preferredLanguageCode ?? "" },
            set: { localization.setPreferredLanguage(code: $0.isEmpty ? nil : $0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        )
    }

    private var vaultAutoProtectBinding: Binding<Bool> {
        Binding(
            get: { vault.autoMode == .intelligent },
            set: { vault.autoMode = $0 ? .intelligent : .manualOnly }
        )
    }
}