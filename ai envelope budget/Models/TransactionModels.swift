//
//  TransactionModels.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import Foundation

// MARK: - Transaction Type

nonisolated enum TransactionType: String, Codable, Sendable, CaseIterable, Identifiable {
    case standard = "STANDARD"
    case ccPayment = "CC_PAYMENT"
    case transfer = "TRANSFER"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .ccPayment: return "CC Payment"
        case .transfer: return "Transfer"
        }
    }

    var icon: String {
        switch self {
        case .standard: return "arrow.left.arrow.right"
        case .ccPayment: return "creditcard.fill"
        case .transfer: return "arrow.triangle.swap"
        }
    }

    var badgeColor: String {
        switch self {
        case .standard: return ""
        case .ccPayment: return "violet"
        case .transfer: return "cyan"
        }
    }

    var isEditable: Bool {
        self == .standard
    }
}

// MARK: - Transaction Response DTO

nonisolated struct TransactionResponse: Codable, Sendable, Identifiable {
    let id: String?
    let appUserId: String?
    let bankAccountId: String?
    let envelopeId: String?
    let amount: Decimal
    let description: String?
    let transactionDate: String?
    let transactionType: String?
    let linkedTransactionId: String?
    let createdAt: String?
    let pending: Bool?
    let merchantName: String?
    let plaidCategory: String?
    let plaidTransactionId: String?

    /// Resolved transaction type
    var resolvedType: TransactionType {
        guard let raw = transactionType else { return .standard }
        return TransactionType(rawValue: raw) ?? .standard
    }

    /// Whether this is from Plaid
    var isPlaid: Bool {
        plaidTransactionId != nil && !plaidTransactionId!.isEmpty
    }

    /// Whether this transaction can be edited (only standard)
    var isEditable: Bool {
        resolvedType.isEditable
    }

    /// Primary display text — merchantName or description
    var displayTitle: String {
        if let merchant = merchantName, !merchant.isEmpty {
            return merchant
        }
        return description ?? "Transaction"
    }

    /// Secondary display text — description if different from merchant
    var displaySubtitle: String? {
        guard let desc = description, !desc.isEmpty,
              let merchant = merchantName, !merchant.isEmpty,
              desc != merchant else { return nil }
        return desc
    }

    /// Whether amount is positive (income/refund/deposit)
    var isIncome: Bool {
        amount > 0
    }

    /// Parsed transaction date
    var parsedDate: Date? {
        guard let dateStr = transactionDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }

    /// Formatted date for display
    var formattedDate: String {
        guard let date = parsedDate else { return transactionDate ?? "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Create Transaction Request

nonisolated struct CreateTransactionRequest: Codable, Sendable {
    let bankAccountId: String
    let envelopeId: String?
    let amount: Decimal
    let description: String?
    let transactionDate: String
    let merchantName: String?
}

// MARK: - Update Transaction Request

nonisolated struct UpdateTransactionRequest: Codable, Sendable {
    let id: String
    let appUserId: String
    let bankAccountId: String
    let envelopeId: String?
    let amount: Decimal
    let description: String?
    let transactionDate: String
    let merchantName: String?
}

// MARK: - CC Payment Request

nonisolated struct CCPaymentRequest: Codable, Sendable {
    let bankAccountId: String
    let creditCardId: String
    let amount: Decimal
    let description: String?
    let transactionDate: String
}

// MARK: - Transfer Request

nonisolated struct TransferRequest: Codable, Sendable {
    let sourceAccountId: String
    let destinationAccountId: String
    let amount: Decimal
    let merchantName: String?
    let description: String?
    let transactionDate: String
}
