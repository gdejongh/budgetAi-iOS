//
//  PlaidModels.swift
//  ai envelope budget
//
//  Created on 3/4/26.
//

import Foundation

// MARK: - Link Token Response

nonisolated struct LinkTokenResponse: Codable, Sendable {
    let linkToken: String
}

// MARK: - Exchange Token Request

nonisolated struct ExchangeTokenRequest: Codable, Sendable {
    let publicToken: String
    let institutionId: String?
    let institutionName: String?
    let accountLinks: [PlaidAccountLink]
}

// MARK: - Plaid Account Link

nonisolated struct PlaidAccountLink: Codable, Sendable {
    let plaidAccountId: String
    let existingBankAccountId: String?
    let accountName: String?
    let accountType: String?
    let mask: String?
}

// MARK: - Plaid Item Response

nonisolated struct PlaidItemResponse: Codable, Sendable, Identifiable {
    let id: String?
    let institutionId: String?
    let institutionName: String?
    let status: String?
    let lastSyncedAt: String?
    let createdAt: String?
    let accounts: [BankAccountResponse]?

    /// Status display with color hint
    var resolvedStatus: PlaidItemStatus {
        guard let status else { return .unknown }
        return PlaidItemStatus(rawValue: status) ?? .unknown
    }

    /// Number of linked accounts
    var accountCount: Int {
        accounts?.count ?? 0
    }
}

// MARK: - Plaid Item Status

nonisolated enum PlaidItemStatus: String, Codable, Sendable {
    case active = "ACTIVE"
    case error = "ERROR"
    case revoked = "REVOKED"
    case unknown = "UNKNOWN"

    var displayName: String {
        switch self {
        case .active: return "Connected"
        case .error: return "Error"
        case .revoked: return "Revoked"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .revoked: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Sync Result Response

nonisolated struct SyncResultResponse: Codable, Sendable {
    let itemsSynced: Int
    let itemsFailed: Int
    let message: String
}

// MARK: - Plaid Link Account (local model for Plaid Link SDK callback)

/// Represents an account returned by the Plaid Link SDK after the user
/// selects accounts. Used to build the account mapping UI before exchange.
nonisolated struct PlaidLinkAccount: Sendable, Identifiable {
    let id: String
    let name: String
    let mask: String?
    let type: String
    let subtype: String?

    /// Masked account number display (e.g., "••••1234")
    var maskedNumber: String? {
        guard let mask, !mask.isEmpty else { return nil }
        return "••••\(mask)"
    }

    /// Map Plaid account type/subtype to our AccountType
    var suggestedAccountType: AccountType {
        switch type.lowercased() {
        case "credit":
            return .creditCard
        case "depository":
            switch subtype?.lowercased() {
            case "savings":
                return .savings
            default:
                return .checking
            }
        default:
            return .checking
        }
    }
}

// MARK: - Plaid Link Result (aggregates SDK callback data)

/// Holds the full result of a successful Plaid Link session.
nonisolated struct PlaidLinkResult: Sendable {
    let publicToken: String
    let institutionName: String?
    let institutionId: String?
    let accounts: [PlaidLinkAccount]
}
