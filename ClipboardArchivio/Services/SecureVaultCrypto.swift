import CryptoKit
import Foundation

struct VaultPayload: Codable {
    var content: String?
    var fileName: String?
    var fileSize: Int64?
    var uti: String?
    var assetData: Data?
    var thumbnailData: Data?
}

enum SecureVaultCrypto {
    static func encrypt(_ payload: VaultPayload, key: SymmetricKey) throws -> Data {
        let plain = try JSONEncoder().encode(payload)
        let sealed = try AES.GCM.seal(plain, using: key)
        guard let combined = sealed.combined else {
            throw SecureKeychainError.keyGenerationFailed
        }
        return combined
    }

    static func decrypt(_ data: Data, key: SymmetricKey) throws -> VaultPayload {
        let box = try AES.GCM.SealedBox(combined: data)
        let plain = try AES.GCM.open(box, using: key)
        return try JSONDecoder().decode(VaultPayload.self, from: plain)
    }

    static func encryptArchive(_ items: [ClipboardItem], key: SymmetricKey) throws -> Data {
        let plain = try JSONEncoder().encode(items)
        let sealed = try AES.GCM.seal(plain, using: key)
        guard let combined = sealed.combined else {
            throw SecureKeychainError.keyGenerationFailed
        }
        return combined
    }

    static func decryptArchive(_ data: Data, key: SymmetricKey) throws -> [ClipboardItem] {
        let box = try AES.GCM.SealedBox(combined: data)
        let plain = try AES.GCM.open(box, using: key)
        return try JSONDecoder().decode([ClipboardItem].self, from: plain)
    }
}