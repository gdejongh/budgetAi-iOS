//
//  KeychainManager.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import Foundation
import Security

nonisolated final class KeychainManager: Sendable {
    static let shared = KeychainManager()

    private let service = "com.budgetai.auth"

    private init() {}

    // MARK: - Keys

    nonisolated enum Key: String {
        case accessToken
        case refreshToken
        case userId
        case email
    }

    // MARK: - Save

    @discardableResult
    func save(_ value: String, for key: Key) -> Bool {
        let data = Data(value.utf8)

        // Delete any existing item first
        delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            // Retry once — handles rare Keychain contention or timing issues
            delete(key)
            let retryStatus = SecItemAdd(query as CFDictionary, nil)
            return retryStatus == errSecSuccess
        }
        return true
    }

    // MARK: - Retrieve

    func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Clear All

    func clearAll() {
        for key in [Key.accessToken, .refreshToken, .userId, .email] {
            delete(key)
        }
    }

    // MARK: - Convenience

    func saveAuthResponse(_ response: AuthResponse) {
        save(response.accessToken, for: .accessToken)
        save(response.refreshToken, for: .refreshToken)
        save(response.userId, for: .userId)
        save(response.email, for: .email)
    }

    var hasTokens: Bool {
        self.get(.accessToken) != nil && self.get(.refreshToken) != nil
    }
}
