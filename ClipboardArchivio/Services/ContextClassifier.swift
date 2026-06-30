import Foundation

enum ContextClassifier {
    static func classify(
        type: ClipboardContentType,
        content: String?,
        fileName: String?,
        sourceBundleId: String?,
        sourceAppName: String?
    ) -> ClipboardContextCategory {
        switch type {
        case .image:
            if isScreenshot(bundleId: sourceBundleId, fileName: fileName) {
                return .screenshot
            }
            return .image
        case .file:
            if ClipboardMediaTypes.isDocument(fileName: fileName) { return .document }
            return .file
        case .text:
            let text = content ?? ""
            if containsURL(text) { return .link }
            if looksLikeCode(text) { return .code }
            return .text
        }
    }

    /// Stable section identifier for grouping (not localized).
    static func sectionKey(for item: ClipboardItem) -> String {
        if item.isVaulted { return "vault" }
        if item.isPinned { return "pinned" }
        if Calendar.current.isDateInToday(item.createdAt) { return "today" }
        if Calendar.current.isDateInYesterday(item.createdAt) { return "yesterday" }
        if let app = item.sourceAppName, !app.isEmpty { return "app:\(app)" }
        return "category:\(item.contextCategory.rawValue)"
    }

    static func localizedSectionTitle(for key: String) -> String {
        switch key {
        case "vault": return L10n.Section.vault
        case "pinned": return L10n.Section.pinned
        case "today": return L10n.Section.today
        case "yesterday": return L10n.Section.yesterday
        default:
            if key.hasPrefix("app:") {
                return String(key.dropFirst(4))
            }
            if key.hasPrefix("category:") {
                let raw = String(key.dropFirst(9))
                return ClipboardContextCategory(rawValue: raw)?.label ?? raw
            }
            return key
        }
    }

    static func sectionIcon(for item: ClipboardItem) -> String {
        if item.isVaulted { return "lock.shield" }
        if item.isPinned { return "pin.fill" }
        if Calendar.current.isDateInToday(item.createdAt) { return "sun.max" }
        if Calendar.current.isDateInYesterday(item.createdAt) { return "moon" }
        if let bundleId = item.sourceBundleId, let icon = appIconName(bundleId: bundleId) {
            return icon
        }
        return item.contextCategory.systemImage
    }

    private static func isScreenshot(bundleId: String?, fileName: String?) -> Bool {
        if bundleId == "com.apple.screencaptureui" { return true }
        if let name = fileName?.lowercased() {
            return name.contains("screenshot") || name.hasPrefix("schermata")
        }
        return false
    }

    private static func containsURL(_ text: String) -> Bool {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, options: [], range: range) != nil
    }

    private static func looksLikeCode(_ text: String) -> Bool {
        let indicators = [
            "func ", "function ", "class ", "import ", "const ", "let ", "var ",
            "def ", "#include", "public ", "private ", "return ", "=>", "->",
            "{", "}", "();", "</", "<?", "#!/"
        ]
        let lines = text.components(separatedBy: .newlines)
        if lines.count >= 3 {
            let codeLineCount = lines.filter { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                return indicators.contains { t.contains($0) }
            }.count
            if codeLineCount >= 2 { return true }
        }
        return indicators.prefix(6).contains { text.contains($0) }
    }

    private static func appIconName(bundleId: String) -> String? {
        switch bundleId {
        case "com.apple.Safari": return "safari"
        case "com.google.Chrome": return "globe"
        case "com.apple.finder": return "folder"
        case "com.microsoft.VSCode": return "chevron.left.forwardslash.chevron.right"
        case "com.apple.Notes": return "note.text"
        default: return nil
        }
    }
}