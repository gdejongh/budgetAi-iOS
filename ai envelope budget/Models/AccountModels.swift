//
//  AccountModels.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import Foundation

// MARK: - Account Type

nonisolated enum AccountType: String, Codable, Sendable, CaseIterable, Identifiable {
    case checking = "CHECKING"
    case savings = "SAVINGS"
    case creditCard = "CREDIT_CARD"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .checking: return "Checking"
        case .savings: return "Savings"
        case .creditCard: return "Credit Card"
        }
    }

    var icon: String {
        switch self {
        case .checking: return "building.columns.fill"
        case .savings: return "banknote.fill"
        case .creditCard: return "creditcard.fill"
        }
    }

    var isCreditCard: Bool { self == .creditCard }
}

// MARK: - Response DTO

nonisolated struct BankAccountResponse: Codable, Sendable, Identifiable {
    let id: String?
    let appUserId: String?
    let name: String
    let accountType: AccountType?
    let currentBalance: Decimal
    let plaidAccountId: String?
    let plaidItemId: String?
    let accountMask: String?
    let manual: Bool?
    let institutionName: String?
    let plaidLinkedAt: String?
    let createdAt: String?

    /// Resolved account type, defaulting to .checking
    var resolvedType: AccountType {
        accountType ?? .checking
    }

    /// Whether this account is linked via Plaid
    var isPlaidLinked: Bool {
        manual == false
    }

    /// Masked account number display (e.g., "••••1234")
    var maskedNumber: String? {
        guard let mask = accountMask, !mask.isEmpty else { return nil }
        return "••••\(mask)"
    }
}

// MARK: - Create Request DTO

nonisolated struct CreateBankAccountRequest: Codable, Sendable {
    let name: String
    let accountType: AccountType?
    let currentBalance: Decimal
}

// MARK: - Update Request DTO

/// Sent as PUT /api/bank-accounts/{id}. Mirrors BankAccountDTO shape.
nonisolated struct UpdateBankAccountRequest: Codable, Sendable {
    let id: String
    let appUserId: String
    let name: String
    let accountType: AccountType
    let currentBalance: Decimal
}

// MARK: - Reconcile Request DTO

nonisolated struct ReconcileBalanceRequest: Codable, Sendable {
    let targetBalance: Decimal
}
