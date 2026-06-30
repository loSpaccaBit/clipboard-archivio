import Foundation

@MainActor
final class EncryptionSettings: ObservableObject {
    @Published var encryptFullArchive: Bool {
        didSet {
            UserDefaults.standard.set(encryptFullArchive, forKey: Keys.encryptFullArchive)
            onSettingChanged?()
        }
    }

    var onSettingChanged: (() -> Void)?

    private enum Keys {
        static let encryptFullArchive = "encryption.fullArchive"
    }

    init() {
        encryptFullArchive = UserDefaults.standard.bool(forKey: Keys.encryptFullArchive)
    }
}