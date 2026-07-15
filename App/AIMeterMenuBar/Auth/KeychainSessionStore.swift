import Foundation
import Security
import AIMeterKit

/// Wraps Keychain Services to persist `ClaudeSessionCredentials`. App
/// target only — the widget extension never links this file and has no
/// Keychain access group of its own.
struct KeychainSessionStore {
    private let service = "com.aimeter.session"
    private let account = "claude-ai-session"

    func save(_ credentials: ClaudeSessionCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        SecItemDelete(baseQuery() as CFDictionary)

        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainSessionStoreError.unhandled(status)
        }
    }

    func load() -> ClaudeSessionCredentials? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(ClaudeSessionCredentials.self, from: data)
    }

    func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum KeychainSessionStoreError: Error {
    case unhandled(OSStatus)
}
