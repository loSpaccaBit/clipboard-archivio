import CryptoKit
import Foundation
import Security

enum SecureKeychainError: Error {
    case keyGenerationFailed
    case keyNotFound
    case keychainError(OSStatus)
}

/// Gestione chiavi simmetriche nel Keychain del Mac (solo su questo dispositivo, utente sbloccato).
final class SecureKeychain {
    static let shared = SecureKeychain()

    private let vaultKeyAccount = "com.clipboardarchivio.vaultEncryptionKey"
    private let archiveKeyAccount = "com.clipboardarchivio.archiveEncryptionKey"
    private let service = "com.clipboardarchivio.secure"

    private init() {}

    func vaultKey() throws -> SymmetricKey {
        try key(account: vaultKeyAccount)
    }

    func archiveKey() throws -> SymmetricKey {
        try key(account: archiveKeyAccount)
    }

    func ensureVaultKey() throws -> SymmetricKey {
        try ensureKey(account: vaultKeyAccount)
    }

    func ensureArchiveKey() throws -> SymmetricKey {
        try ensureKey(account: archiveKeyAccount)
    }

    private func ensureKey(account: String) throws -> SymmetricKey {
        if let existing = try? key(account: account) {
            return existing
        }
        let raw = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        try store(raw, account: account)
        return SymmetricKey(data: raw)
    }

    private func key(account: String) throws -> SymmetricKey {
        var query: [String: Any] = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw status == errSecItemNotFound ? SecureKeychainError.keyNotFound : SecureKeychainError.keychainError(status)
        }
        return SymmetricKey(data: data)
    }

    private func store(_ data: Data, account: String) throws {
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureKeychainError.keychainError(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}