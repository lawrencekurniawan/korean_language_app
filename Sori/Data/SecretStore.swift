import Foundation
import Security

enum SecretKey: String, CaseIterable, Sendable {
    case openSubtitlesAPIKey = "opensubtitles.apiKey"
    case openSubtitlesUsername = "opensubtitles.username"
    case openSubtitlesPassword = "opensubtitles.password"
    case omdbAPIKey = "omdb.apiKey"

    var title: String {
        switch self {
        case .openSubtitlesAPIKey: "OpenSubtitles API key"
        case .openSubtitlesUsername: "OpenSubtitles username"
        case .openSubtitlesPassword: "OpenSubtitles password"
        case .omdbAPIKey: "OMDb API key"
        }
    }
}

/// Credentials live in the Keychain with `ThisDeviceOnly` accessibility, so
/// they are excluded from backups and never enter the SQLite snapshot.
struct SecretStore: Sendable {
    static let shared = SecretStore()

    private let service = "com.lawrencekurniawan.sori.secrets"

    func value(for key: SecretKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func set(_ value: String?, for key: SecretKey) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(base as CFDictionary)

        guard let value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = value.data(using: .utf8) else {
            return true
        }

        var attributes = base
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    func clearAll() {
        for key in SecretKey.allCases {
            set(nil, for: key)
        }
    }
}
