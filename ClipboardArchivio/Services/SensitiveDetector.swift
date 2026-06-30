import Foundation

struct SensitiveAnalysis {
    let score: Int
    let reasons: [String]
    let threshold: Int

    var shouldVault: Bool { score >= threshold }

    var summary: String {
        reasons.isEmpty ? "Nessun segnale" : reasons.joined(separator: ", ")
    }
}

enum VaultSensitivity: String, CaseIterable, Identifiable {
    case relaxed
    case balanced
    case strict

    var id: String { rawValue }

    var label: String {
        switch self {
        case .relaxed: return L10n.VaultMode.relaxed
        case .balanced: return L10n.VaultMode.balanced
        case .strict: return L10n.VaultMode.strict
        }
    }

    var threshold: Int {
        switch self {
        case .relaxed: return 6
        case .balanced: return 4
        case .strict: return 2
        }
    }
}

enum SensitiveDetector {
    static func analyze(text: String, sensitivity: VaultSensitivity = .balanced) -> SensitiveAnalysis {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SensitiveAnalysis(score: 0, reasons: [], threshold: sensitivity.threshold)
        }

        let lower = trimmed.lowercased()
        var score = 0
        var reasons: [String] = []

        if let reason = matchHighConfidence(in: trimmed) {
            return SensitiveAnalysis(score: 100, reasons: [reason], threshold: sensitivity.threshold)
        }

        score += scoreKeywords(in: lower, reasons: &reasons)
        score += scoreStructuredSecrets(in: trimmed, lower: lower, reasons: &reasons)
        score += scoreFinancialPatterns(in: trimmed, reasons: &reasons)
        score += scoreContextualPatterns(in: trimmed, lower: lower, reasons: &reasons)
        score += scoreNegativeSignals(in: trimmed, lower: lower)

        return SensitiveAnalysis(score: max(0, score), reasons: reasons, threshold: sensitivity.threshold)
    }

    static func isSensitive(text: String, sensitivity: VaultSensitivity = .balanced) -> Bool {
        analyze(text: text, sensitivity: sensitivity).shouldVault
    }

    // MARK: - High confidence

    private static func matchHighConfidence(in text: String) -> String? {
        let patterns: [(String, String)] = [
            (#"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"#, "Chiave privata"),
            (#"-----BEGIN CERTIFICATE-----"#, "Certificato"),
            (#"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"#, "Token JWT"),
            (#"\bAKIA[0-9A-Z]{16}\b"#, "Chiave AWS"),
            (#"\bghp_[A-Za-z0-9]{20,}\b"#, "Token GitHub"),
            (#"\bgithub_pat_[A-Za-z0-9_]{20,}\b"#, "Token GitHub"),
            (#"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"#, "Token Slack"),
            (#"\bsk_(?:live|test)_[A-Za-z0-9]{16,}\b"#, "Chiave Stripe"),
            (#"\bAIza[0-9A-Za-z_-]{20,}\b"#, "Chiave Google API"),
            (#"mongodb(\+srv)?://[^:\s]+:[^@\s]+@"#, "Stringa di connessione"),
            (#"postgres(?:ql)?://[^:\s]+:[^@\s]+@"#, "Stringa di connessione"),
            (#"mysql://[^:\s]+:[^@\s]+@"#, "Stringa di connessione"),
            (#"redis://[^:\s]+:[^@\s]+@"#, "Stringa di connessione"),
            (#"sftp://[^:\s]+:[^@\s]+@"#, "Stringa di connessione"),
        ]

        for (pattern, reason) in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return reason
            }
        }
        return nil
    }

    // MARK: - Scored signals

    private static func scoreKeywords(in lower: String, reasons: inout [String]) -> Int {
        let keywords: [(String, Int, String)] = [
            ("password", 3, "Password"),
            ("passwd", 3, "Password"),
            ("passcode", 3, "Passcode"),
            ("pin code", 3, "PIN"),
            ("pin:", 2, "PIN"),
            ("secret", 2, "Segreto"),
            ("api_key", 3, "API key"),
            ("apikey", 3, "API key"),
            ("access_key", 3, "Access key"),
            ("private_key", 4, "Chiave privata"),
            ("bearer ", 3, "Bearer token"),
            ("authorization:", 3, "Authorization"),
            ("otp", 2, "OTP"),
            ("2fa", 2, "2FA"),
            ("cvv", 3, "CVV"),
            ("cvc", 3, "CVC"),
            ("codice fiscale", 3, "Codice fiscale"),
            ("numero carta", 3, "Carta"),
            ("carta di credito", 4, "Carta"),
            ("ssh-rsa", 4, "Chiave SSH"),
            ("ssh-ed25519", 4, "Chiave SSH"),
            ("client_secret", 4, "Client secret"),
            ("refresh_token", 3, "Refresh token"),
            ("auth_token", 3, "Auth token"),
        ]

        var added = 0
        for (term, weight, reason) in keywords {
            if lower.contains(term), !reasons.contains(reason) {
                added += weight
                reasons.append(reason)
            }
        }
        return added
    }

    private static func scoreStructuredSecrets(
        in text: String,
        lower: String,
        reasons: inout [String]
    ) -> Int {
        var score = 0

        let envPatterns = [
            (#"(?i)(?:password|passwd|secret|token|api[_-]?key)\s*[=:]\s*\S+"#, "Variabile d'ambiente"),
            (#"(?i)"(?:password|secret|token)"\s*:\s*"[^"]{4,}""#, "JSON con segreto"),
        ]
        for (pattern, reason) in envPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil, !reasons.contains(reason) {
                score += 4
                reasons.append(reason)
            }
        }

        if lower.hasPrefix("basic ") && text.count > 12 {
            if !reasons.contains("Basic auth") {
                score += 4
                reasons.append("Basic auth")
            }
        }

        if text.range(of: #"[A-Fa-f0-9]{32,}"#, options: .regularExpression) != nil,
           reasons.contains(where: { $0.contains("API") || $0.contains("token") || $0.contains("Password") || $0.contains("Segreto") }) {
            score += 2
        }

        return score
    }

    private static func scoreFinancialPatterns(in text: String, reasons: inout [String]) -> Int {
        var score = 0

        if let cardReason = detectCreditCard(in: text) {
            score += 5
            reasons.append(cardReason)
        }

        if text.range(of: #"\bIT\d{2}[A-Z0-9]{23}\b"#, options: .regularExpression) != nil {
            score += 5
            reasons.append("IBAN")
        }

        if text.range(of: #"\b[A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z]\b"#, options: .regularExpression) != nil {
            score += 4
            reasons.append("Codice fiscale")
        }

        return score
    }

    private static func scoreContextualPatterns(
        in text: String,
        lower: String,
        reasons: inout [String]
    ) -> Int {
        var score = 0

        if text.range(of: #"https?://[^/\s:]+:[^@\s]+@"#, options: .regularExpression) != nil {
            score += 4
            reasons.append("Credenziali in URL")
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let credentialLabels = ["username", "user", "login", "email", "password", "pass", "otp", "token", "pin"]
        let matchingLines = lines.filter { line in
            let l = line.lowercased()
            return credentialLabels.contains { l.contains("\($0):") || l.contains("\($0) =") }
        }
        if matchingLines.count >= 2 {
            score += 3
            reasons.append("Blocco credenziali")
        }

        if trimmedSingleLineIsSecretLike(text, lower: lower) {
            score += 3
            reasons.append("Stringa segreta")
        }

        return score
    }

    private static func trimmedSingleLineIsSecretLike(_ text: String, lower: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("\n"), trimmed.count >= 24, trimmed.count <= 128 else { return false }

        let hasLetter = trimmed.contains(where: \.isLetter)
        let hasNumber = trimmed.contains(where: \.isNumber)
        let hasSymbol = trimmed.contains(where: { !$0.isLetter && !$0.isNumber })
        guard hasLetter, hasNumber else { return false }

        let wordCount = lower.split(whereSeparator: { $0.isWhitespace }).count
        guard wordCount <= 3 else { return false }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-./+=:"))
        let mostlyToken = trimmed.unicodeScalars.filter { allowed.contains($0) }.count >= trimmed.unicodeScalars.count * 9 / 10
        return mostlyToken && (hasSymbol || trimmed.count >= 32)
    }

    private static func scoreNegativeSignals(in text: String, lower: String) -> Int {
        var penalty = 0
        let words = lower.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        if words.count > 35 { penalty -= 3 }
        if text.count > 800, words.count > 60 { penalty -= 2 }
        if lower.contains("http://") || lower.contains("https://"), words.count > 15,
           !lower.contains("password"), !lower.contains("token") {
            penalty -= 2
        }
        return penalty
    }

    // MARK: - Credit card (Luhn)

    private static func detectCreditCard(in text: String) -> String? {
        let pattern = #"(?:\d[ -]*?){13,19}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for match in matches {
            guard let swiftRange = Range(match.range, in: text) else { continue }
            let fragment = String(text[swiftRange])
            let digits = fragment.filter(\.isNumber)
            if luhnValid(digits) { return "Carta di credito" }
        }
        return nil
    }

    private static func luhnValid(_ digits: String) -> Bool {
        let nums = digits.compactMap { Int(String($0)) }
        guard nums.count >= 13, nums.count <= 19 else { return false }
        var sum = 0
        for (index, digit) in nums.reversed().enumerated() {
            var value = digit
            if index % 2 == 1 {
                value *= 2
                if value > 9 { value -= 9 }
            }
            sum += value
        }
        return sum % 10 == 0
    }
}