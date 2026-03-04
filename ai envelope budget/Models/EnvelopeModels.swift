//
//  EnvelopeModels.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import Foundation

// MARK: - Envelope Type

nonisolated enum EnvelopeType: String, Codable, Sendable {
    case standard = "STANDARD"
    case ccPayment = "CC_PAYMENT"

    var isCCPayment: Bool { self == .ccPayment }
}

// MARK: - Goal Type

nonisolated enum GoalType: String, Codable, Sendable, CaseIterable, Identifiable {
    case monthly = "MONTHLY"
    case weekly = "WEEKLY"
    case target = "TARGET"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        case .target: return "Target"
        }
    }

    var icon: String {
        switch self {
        case .monthly: return "calendar"
        case .weekly: return "calendar.badge.clock"
        case .target: return "flag.checkered"
        }
    }
}

// MARK: - Envelope Response DTO

nonisolated struct EnvelopeResponse: Codable, Sendable, Identifiable {
    let id: String?
    let appUserId: String?
    let envelopeCategoryId: String?
    let name: String
    let allocatedBalance: Decimal
    let envelopeType: EnvelopeType?
    let linkedAccountId: String?
    let goalAmount: Decimal?
    let monthlyGoalTarget: Decimal?
    let goalTargetDate: String?
    let goalType: GoalType?
    let createdAt: String?

    /// Resolved type defaulting to .standard
    var resolvedType: EnvelopeType {
        envelopeType ?? .standard
    }

    var isCCPayment: Bool {
        resolvedType.isCCPayment
    }

    var hasGoal: Bool {
        goalType != nil
    }
}

// MARK: - Create Envelope Request

nonisolated struct CreateEnvelopeRequest: Codable, Sendable {
    let name: String
    let allocatedBalance: Decimal
    let envelopeCategoryId: String
}

// MARK: - Set Allocation Request

nonisolated struct SetAllocationRequest: Codable, Sendable {
    let amount: Decimal
}

// MARK: - Envelope Allocation Response

nonisolated struct EnvelopeAllocationResponse: Codable, Sendable {
    let envelopeId: String?
    let yearMonth: String?
    let amount: Decimal?
}

// MARK: - Envelope Spent Summary Response

nonisolated struct EnvelopeSpentSummaryResponse: Codable, Sendable {
    let envelopeId: String?
    let totalSpent: Decimal?
    let periodSpent: Decimal?
}

// MARK: - Envelope Category Response

nonisolated struct EnvelopeCategoryResponse: Codable, Sendable, Identifiable {
    let id: String?
    let appUserId: String?
    let name: String
    let categoryType: EnvelopeType?
    let createdAt: String?

    var resolvedType: EnvelopeType {
        categoryType ?? .standard
    }

    var isCCPayment: Bool {
        resolvedType.isCCPayment
    }
}

// MARK: - Create Category Request

nonisolated struct CreateEnvelopeCategoryRequest: Codable, Sendable {
    let name: String
}
