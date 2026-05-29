import Foundation
import Security

/// Tiny wrapper around `Security.framework` to read/write a single password
/// (the GitLab personal access token) in the user's login keychain.
enum KeychainHelper {
    private static let service = AppConstants.keychainService
    private static let account = AppConstants.keychainAccount

    static func saveToken(_ token: String, serverID: UUID? = nil) throws {
        let data = Data(token.utf8)
        let acc = accountKey(for: serverID)
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  acc,
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

    static func loadToken(serverID: UUID? = nil) -> String? {
        let acc = accountKey(for: serverID)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: acc,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status != errSecSuccess {
            AppLogger.settings.error("keychain load failed: OSStatus \(status, privacy: .public)")
            return nil
        }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteToken(serverID: UUID? = nil) {
        let acc = accountKey(for: serverID)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: acc,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Legacy single-server uses `gitlab-pat`; per-server keys use `gitlab-pat:<uuid>`.
    private static func accountKey(for serverID: UUID?) -> String {
        if let id = serverID { return "\(account):\(id.uuidString)" }
        return account
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
