import Foundation
import Security

/// Tiny wrapper around `Security.framework` to read/write a single password
/// (the GitLab personal access token) in the user's login keychain.
enum KeychainHelper {
    private static let service = AppConstants.keychainService
    private static let account = AppConstants.keychainAccount

    static func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        // Update if existing, otherwise add.
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  account,
        ]
        let attrs: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            if addStatus != errSecSuccess {
                throw KeychainError.osStatus(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.osStatus(status)
        }
    }

    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: LocalizedError {
        case osStatus(OSStatus)
        var errorDescription: String? {
            switch self {
            case .osStatus(let s): return "Keychain error (\(s))"
            }
        }
    }
}
