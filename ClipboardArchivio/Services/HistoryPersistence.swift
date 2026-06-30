import Foundation

/// Encode e scrittura archivio su disco (fuori dal MainActor).
enum HistoryPersistence {
    private static let queue = DispatchQueue(label: "com.clipboardarchivio.save", qos: .utility)

    static func write(
        snapshot: [ClipboardItem],
        encrypt: Bool,
        plainURL: URL,
        encryptedURL: URL,
        waitUntilDone: Bool = false
    ) {
        let work = {
            performWrite(snapshot: snapshot, encrypt: encrypt, plainURL: plainURL, encryptedURL: encryptedURL)
        }
        if waitUntilDone {
            queue.sync(execute: work)
        } else {
            queue.async(execute: work)
        }
    }

    private static func performWrite(
        snapshot: [ClipboardItem],
        encrypt: Bool,
        plainURL: URL,
        encryptedURL: URL
    ) {
        do {
            if encrypt {
                let key = try SecureKeychain.shared.ensureArchiveKey()
                let data = try SecureVaultCrypto.encryptArchive(snapshot, key: key)
                try data.write(to: encryptedURL, options: .atomic)
                try? FileManager.default.removeItem(at: plainURL)
            } else {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: plainURL, options: .atomic)
                try? FileManager.default.removeItem(at: encryptedURL)
            }
        } catch {}
    }
}