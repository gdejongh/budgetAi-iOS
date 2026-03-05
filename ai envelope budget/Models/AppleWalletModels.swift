//
//  AppleWalletModels.swift
//  ai envelope budget
//
//  Created on 3/5/26.
//

import Foundation

// MARK: - Apple Wallet Account (Local Mapping)

/// Persisted mapping between a FinanceKit account and a backend BankAccount.
/// Stored locally via UserDefaults since FinanceKit has no server-side counterpart.
nonisolated struct AppleWalletAccountLink: Codable, Sendable, Identifiable {
    /// FinanceKit account identifier
    let financeKitAccountId: String
    /// Backend BankAccount id
    let bankAccountId: String
    /// Display name (e.g., "Apple Card", "Apple Cash")
    let accountName: String
    /// Account type mapped to the app's AccountType
    let accountType: AccountType
    /// Institution name for display
    let institutionName: String
    /// When this link was created
    let linkedAt: Date
    /// Last successful sync timestamp
    var lastSyncedAt: Date?

    var id: String { financeKitAccountId }
}

// MARK: - Sync State

/// Observable sync state for UI feedback.
nonisolated enum AppleWalletSyncState: Sendable, Equatable {
    case idle
    case syncing
    case success(newTransactions: Int)
    case error(String)

    var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }
}

// MARK: - Authorization Status (mirrors FinanceKit)

nonisolated enum AppleWalletAuthStatus: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied

    var displayName: String {
        switch self {
        case .notDetermined: return "Not Connected"
        case .authorized: return "Connected"
        case .denied: return "Access Denied"
        }
    }
}

// MARK: - Discovered Account

/// An Apple Wallet account discovered via FinanceKit, presented to the user
/// for selection before linking. Analogous to PlaidLinkAccount.
nonisolated struct DiscoveredAppleWalletAccount: Sendable, Identifiable {
    let id: String
    let name: String
    let institutionName: String
    let accountType: AccountType
    let currentBalance: Decimal
    /// Whether this account is already linked via Plaid (duplicate detection)
    var isAlreadyLinkedViaPlaid: Bool = false
    /// Whether this account is already linked via Apple Wallet
    var isAlreadyLinkedViaWallet: Bool = false

    var isLinkable: Bool {
        !isAlreadyLinkedViaPlaid && !isAlreadyLinkedViaWallet
    }
}

// MARK: - Persistence Keys

enum AppleWalletStorage {
    static let linkedAccountsKey = "apple_wallet_linked_accounts"
    static let lastSyncTimestampKey = "apple_wallet_last_sync_timestamp"

    /// Save linked accounts to UserDefaults
    static func saveLinkedAccounts(_ accounts: [AppleWalletAccountLink]) {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        UserDefaults.standard.set(data, forKey: linkedAccountsKey)
    }

    /// Load linked accounts from UserDefaults
    static func loadLinkedAccounts() -> [AppleWalletAccountLink] {
        guard let data = UserDefaults.standard.data(forKey: linkedAccountsKey),
              let accounts = try? JSONDecoder().decode([AppleWalletAccountLink].self, from: data)
        else { return [] }
        return accounts
    }

    /// Clear all persisted Apple Wallet data
    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: linkedAccountsKey)
        UserDefaults.standard.removeObject(forKey: lastSyncTimestampKey)
    }
}
