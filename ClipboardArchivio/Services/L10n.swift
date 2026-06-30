import Foundation

/// Typed localization API — all UI strings route through `LocalizationManager`.
enum L10n {
    private static var lm: LocalizationManager { LocalizationManager.shared }

    private static func tr(_ key: String) -> String {
        lm.localized(key)
    }

    private static func fmt(_ key: String, _ args: CVarArg...) -> String {
        String(format: tr(key), locale: lm.formattingLocale, arguments: args)
    }

    static var appName: String { tr("Clipboard Archive") }
    static var preferencesWindowTitle: String { tr("Preferences — Clipboard Archive") }
    static var ok: String { tr("OK") }

    static var clipboardTitle: String { tr("Clipboard") }
    static func itemCount(_ count: Int) -> String { fmt("%lld items", count) }
    static var searchPlaceholder: String { tr("Search clipboard") }
    static var clearSearch: String { tr("Clear search") }

    static var pauseSaving: String { tr("Pause saving") }
    static var resumeSaving: String { tr("Resume saving") }
    static var savingPaused: String { tr("Saving paused") }
    static func resumesIn(_ time: String) -> String { fmt("Resumes in %@", time) }
    static var resume: String { tr("Resume") }
    static var copiesNotSaved: String { tr("Copies will not be saved") }
    static var pauseDuration: String { tr("Pause duration") }
    static var pauseActive: String { tr("Pause active") }
    static var enablePauseSaving: String { tr("Enable pause saving") }

    static func minutes(_ n: Int) -> String { fmt("%lld minutes", n) }
    static func oneHour() -> String { tr("1 hour") }
    static func hours24() -> String { tr("24 hours") }

    static var multiSelect: String { tr("Multi-select") }
    static var multiSelectHelp: String { tr("Multi-select — paste multiple clips together or in sequence") }
    static var multiSelectHint: String { tr("Select multiple clips with checkboxes, then choose how to paste.") }
    static var close: String { tr("Close") }
    static func selectedCount(_ n: Int) -> String { fmt("%lld selected", n) }
    static var selectAtLeastOne: String { tr("Select at least one") }
    static var merge: String { tr("Merge") }
    static var mergeSubtitle: String { tr("Single text") }
    static var sequential: String { tr("Sequential") }
    static var sequentialSubtitle: String { tr("⌘V one at a time") }
    static func pastingProgress(_ progress: String) -> String { fmt("Pasting %@", progress) }
    static var pasteThenNext: String { tr("Paste with ⌘V in the target app, then press Next for the following clip.") }
    static var next: String { tr("Next") }
    static var done: String { tr("Done") }
    static func stackProgress(_ current: Int, _ total: Int) -> String {
        fmt("%1$lld of %2$lld", current, total)
    }

    static var noResults: String { tr("No results") }
    static var noClips: String { tr("No clips") }
    static var copyToStart: String { tr("Copy with ⌘C to get started") }

    static var vault: String { tr("Vault") }
    static var vaultProtected: String { tr("Protected vault") }
    static var vaultTouchIDHint: String { tr("Touch ID required for sensitive clips") }
    static var unlock: String { tr("Unlock") }
    static var inVault: String { tr("In vault") }
    static var protectedContent: String { tr("Protected content") }
    static var moveToVault: String { tr("Move to vault") }
    static var removeFromVault: String { tr("Remove from vault") }
    static var vaultUnlockReason: String { tr("Unlock the sensitive clipboard vault") }
    static var sensitiveVault: String { tr("Sensitive vault") }
    static var vaultOnDisk: String { tr("Vault on disk") }
    static var detection: String { tr("Detection") }
    static var sensitivity: String { tr("Sensitivity") }
    static var vaultAutoDelete: String { tr("Vault auto-delete") }

    static var copyAgain: String { tr("Copy again") }
    static var delete: String { tr("Delete") }
    static var pin: String { tr("Pin") }
    static var unpin: String { tr("Unpin") }
    static var showInFinder: String { tr("Show in Finder") }
    static var pinnedLabel: String { tr("Pinned") }
    static var select: String { tr("Select") }
    static var deselect: String { tr("Deselect") }
    static var copy: String { tr("Copy") }
    static var copied: String { tr("Copied") }

    enum Section {
        static var results: String { tr("Results") }
        static var pinned: String { tr("Pinned") }
        static var vault: String { tr("Vault") }
        static var today: String { tr("Today") }
        static var yesterday: String { tr("Yesterday") }
        static var other: String { tr("Other") }
    }

    enum Settings {
        static var general: String { tr("General") }
        static var language: String { tr("Language") }
        static var appLanguage: String { tr("App language") }
        static var followSystem: String { tr("Follow System") }
        static var launch: String { tr("Startup") }
        static var launchAtLogin: String { tr("Open at Mac login") }
        static var launchFooter: String { tr("The app stays in the menu bar and does not appear in the Dock. You can disable it in System Settings → General → Login Items.") }
        static var history: String { tr("History") }
        static var autoDelete: String { tr("Automatic deletion") }
        static var deleteAfter: String { tr("Delete items after") }
        static var retentionFooter: String { tr("Older items are removed automatically. Pinned and vault items are always excluded.") }
        static var privacyTitle: String { tr("Privacy") }
        static var defaultPauseDuration: String { tr("Default pause duration") }
        static var privacyFooter: String { tr("Pause saving from the archive toolbar. While paused, new copies are not recorded.") }
        static var sensitiveContent: String { tr("Sensitive content") }
        static var vaultAutoProtect: String { tr("Protect sensitive content automatically") }
        static var vaultSimpleFooter: String { tr("Detects passwords, cards and private data locally on your Mac. Touch ID is required to view vault items.") }
        static var security: String { tr("Security") }
        static var encryptArchive: String { tr("Encrypt saved history on this Mac") }
        static var securitySimpleFooter: String { tr("Adds extra protection for your clipboard history. Vault items are always encrypted.") }
        static var openHistory: String { tr("Open archive") }
        static var clearExceptPinnedVault: String { tr("Clear history (except pinned & vault)") }
        static var clearAll: String { tr("Clear all") }
        static var clearAllConfirmTitle: String { tr("Clear all history?") }
        static var clearAllConfirmMessage: String { tr("This removes every saved clip, including pinned items. Vault items are also removed.") }
        static var cancel: String { tr("Cancel") }
        static var preferences: String { tr("Preferences") }
        static var about: String { tr("About") }
        static var versionTitle: String { tr("Version") }
        static var developer: String { tr("Developer") }
        static var license: String { tr("License") }
        static var licenseNotice: String {
            tr("Licensed under GNU General Public License v3.0 or later")
        }
        static func version(_ short: String, _ build: String) -> String {
            fmt("Version %1$@ (%2$@)", short, build)
        }
        static func copyright(_ year: Int, _ name: String) -> String {
            fmt("Copyright © %1$lld %2$@", year, name)
        }
        static var launchLoginError: String { tr("Requires macOS 13 or later.") }
    }

    enum Menu {
        static var openArchive: String { tr("Open archive") }
        static var preferences: String { tr("Preferences…") }
        static var quit: String { tr("Quit") }
        static var activeStatus: String { tr("Clipboard Archive") }
        static var pauseActiveStatus: String { tr("Clipboard Archive — saving paused") }
    }

    enum Retention {
        static var never: String { tr("Never") }
        static var days7: String { tr("7 days") }
        static var days14: String { tr("14 days") }
        static var days30: String { tr("30 days") }
        static var days60: String { tr("60 days") }
        static var days90: String { tr("90 days") }
        static var months6: String { tr("6 months") }
        static var year1: String { tr("1 year") }
        static func customDays(_ n: Int) -> String { fmt("%lld days", n) }
        static var autoDeleteOff: String { tr("Automatic deletion disabled") }
        static func deleteAfter(_ label: String) -> String {
            fmt("Delete after %@ (except pinned & vault)", label)
        }
    }

    enum VaultMode {
        static var intelligent: String { tr("Smart automatic") }
        static var manualOnly: String { tr("Manual only") }
        static var relaxed: String { tr("Relaxed") }
        static var balanced: String { tr("Balanced") }
        static var strict: String { tr("Strict") }
        static var manualFooter: String { tr("You decide what goes in the vault: right-click → Move to vault. Vault contents are encrypted on disk (secure/ folder). Touch ID to view and copy. Auto-expiry configurable below.") }
        static var intelligentFooter: String { tr("Local smart detection (no data sent online): JWT, API keys, IBAN, cards, passwords and sensitive context. Vault contents are encrypted with AES-GCM. Touch ID to view and copy. Sensitivity: Relaxed, Balanced, Strict.") }
    }

    enum Content {
        static var text: String { tr("Text") }
        static var image: String { tr("Image") }
        static var images: String { tr("Images") }
        static var file: String { tr("File") }
        static var link: String { tr("Link") }
        static var code: String { tr("Code") }
        static var screenshot: String { tr("Screenshot") }
        static var documents: String { tr("Documents") }
        static var app: String { tr("App") }
        static var emptyText: String { tr("Empty text") }
        static var screenshotFile: String { tr("Screenshot.png") }
        static var imageFile: String { tr("Image.png") }
        static var documentPDF: String { tr("Document.pdf") }
    }

    enum Filter {
        static var all: String { tr("All") }
        static var today: String { tr("Today") }
        static var pinned: String { tr("Pinned") }
        static var vault: String { tr("Vault") }
        static var screenshots: String { tr("Screenshots") }
        static var documents: String { tr("Documents") }
        static var code: String { tr("Code") }
        static var links: String { tr("Links") }
    }
}
