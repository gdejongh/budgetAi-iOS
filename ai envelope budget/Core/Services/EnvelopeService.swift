//
//  EnvelopeService.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class EnvelopeService {
    // MARK: - State

    var envelopes: [EnvelopeResponse] = []
    var categories: [EnvelopeCategoryResponse] = []
    var monthlyAllocations: [EnvelopeAllocationResponse] = []
    var spentSummaries: [EnvelopeSpentSummaryResponse] = []
    var isLoading = false
    var errorMessage: String?

    /// Currently viewed month (first-of-month)
    var viewedMonth: Date = {
        let cal = Calendar.current
        let now = Date()
        return cal.date(from: cal.dateComponents([.year, .month], from: now))!
    }()

    // MARK: - Computed Properties

    /// Categories sorted: CC_PAYMENT first, then alphabetical
    var sortedCategories: [EnvelopeCategoryResponse] {
        categories.sorted { a, b in
            if a.isCCPayment != b.isCCPayment { return a.isCCPayment }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Standard categories only
    var standardCategories: [EnvelopeCategoryResponse] {
        categories.filter { !$0.isCCPayment }
    }

    /// Envelopes grouped by category ID
    var envelopesByCategory: [String: [EnvelopeResponse]] {
        Dictionary(grouping: envelopes) { $0.envelopeCategoryId ?? "" }
    }

    /// Monthly allocation lookup: envelopeId → amount
    var monthlyAllocationMap: [String: Decimal] {
        var map: [String: Decimal] = [:]
        for alloc in monthlyAllocations {
            if let id = alloc.envelopeId {
                map[id] = alloc.amount ?? Decimal.zero
            }
        }
        return map
    }

    /// Spent lookup: envelopeId → |periodSpent| for the viewed month
    var spentMap: [String: Decimal] {
        var map: [String: Decimal] = [:]
        for summary in spentSummaries {
            if let id = summary.envelopeId {
                let spent = summary.periodSpent ?? Decimal.zero
                map[id] = spent < 0 ? -spent : spent
            }
        }
        return map
    }

    /// Total spent all-time lookup: envelopeId → |totalSpent|
    var totalSpentMap: [String: Decimal] {
        var map: [String: Decimal] = [:]
        for summary in spentSummaries {
            if let id = summary.envelopeId {
                let spent = summary.totalSpent ?? Decimal.zero
                map[id] = spent < 0 ? -spent : spent
            }
        }
        return map
    }

    /// Remaining per envelope: allocatedBalance - |totalSpent|
    /// For CC Payment envelopes, uses effective funding (accounting for source shortfall).
    func remaining(
        for envelope: EnvelopeResponse,
        accounts: [BankAccountResponse] = [],
        transactions: [TransactionResponse] = []
    ) -> Decimal {
        let spent = totalSpentMap[envelope.id ?? ""] ?? Decimal.zero
        if envelope.isCCPayment && !accounts.isEmpty {
            let effective = ccEffectiveFunding(for: envelope, accounts: accounts, transactions: transactions)
            return effective - spent
        }
        return envelope.allocatedBalance - spent
    }

    /// Monthly allocation for a specific envelope in the viewed month
    func monthlyAllocation(for envelope: EnvelopeResponse) -> Decimal {
        monthlyAllocationMap[envelope.id ?? ""] ?? Decimal.zero
    }

    /// Monthly spent for a specific envelope
    func monthlySpent(for envelope: EnvelopeResponse) -> Decimal {
        spentMap[envelope.id ?? ""] ?? Decimal.zero
    }

    /// Total of all envelopes' allocatedBalance
    var totalAllocated: Decimal {
        envelopes.reduce(Decimal.zero) { $0 + $1.allocatedBalance }
    }

    /// Total of all monthly allocations for the viewed month
    var totalMonthlyAllocated: Decimal {
        monthlyAllocations.reduce(Decimal.zero) { $0 + ($1.amount ?? Decimal.zero) }
    }

    /// Total remaining across all envelopes
    var totalRemaining: Decimal {
        envelopes.reduce(Decimal.zero) { $0 + remaining(for: $1) }
    }

    /// Total spent this month across all envelopes
    var totalMonthlySpent: Decimal {
        spentMap.values.reduce(Decimal.zero, +)
    }

    /// Total envelopes count
    var envelopeCount: Int {
        envelopes.count
    }

    /// Total categories count
    var categoryCount: Int {
        categories.count
    }

    // MARK: - Dependencies

    private let api: APIClient

    // MARK: - Init

    init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: - Month Navigation

    func previousMonth() {
        let cal = Calendar.current
        if let newMonth = cal.date(byAdding: .month, value: -1, to: viewedMonth) {
            viewedMonth = newMonth
            Task { await loadMonthData() }
        }
    }

    func nextMonth() {
        let cal = Calendar.current
        if let newMonth = cal.date(byAdding: .month, value: 1, to: viewedMonth) {
            viewedMonth = newMonth
            Task { await loadMonthData() }
        }
    }

    var viewedMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: viewedMonth)
    }

    private var viewedMonthParam: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: viewedMonth)
    }

    private var monthStartDate: String { viewedMonthParam }

    private var monthEndDate: String {
        let cal = Calendar.current
        guard let nextMonth = cal.date(byAdding: .month, value: 1, to: viewedMonth),
              let lastDay = cal.date(byAdding: .day, value: -1, to: nextMonth) else {
            return viewedMonthParam
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: lastDay)
    }

    // MARK: - Load All Data

    func loadAll() async {
        isLoading = true
        errorMessage = nil

        do {
            async let categoriesReq: [EnvelopeCategoryResponse] = api.request(
                .get, path: "/api/envelope-categories", authenticated: true
            )
            async let envelopesReq: [EnvelopeResponse] = api.request(
                .get, path: "/api/envelopes", authenticated: true
            )

            categories = try await categoriesReq
            envelopes = try await envelopesReq

            await loadMonthData()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to load envelopes."
        }

        isLoading = false
    }

    /// Load month-specific data (allocations + spent summary)
    func loadMonthData() async {
        do {
            async let allocReq: [EnvelopeAllocationResponse] = api.request(
                .get,
                path: "/api/envelopes/allocations",
                queryItems: [URLQueryItem(name: "month", value: viewedMonthParam)],
                authenticated: true
            )
            async let spentReq: [EnvelopeSpentSummaryResponse] = api.request(
                .get,
                path: "/api/envelopes/spent-summary",
                queryItems: [
                    URLQueryItem(name: "startDate", value: monthStartDate),
                    URLQueryItem(name: "endDate", value: monthEndDate)
                ],
                authenticated: true
            )

            monthlyAllocations = try await allocReq
            spentSummaries = try await spentReq
        } catch {
            // Silently fail for month data — main data is already loaded
        }
    }

    // MARK: - Category CRUD

    func createCategory(name: String) async -> Bool {
        errorMessage = nil
        let request = CreateEnvelopeCategoryRequest(name: name)

        do {
            let newCategory: EnvelopeCategoryResponse = try await api.request(
                .post, path: "/api/envelope-categories", body: request, authenticated: true
            )
            categories.append(newCategory)
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to create category."
            return false
        }
    }

    func deleteCategory(_ category: EnvelopeCategoryResponse) async -> Bool {
        guard let id = category.id else { return false }
        errorMessage = nil

        do {
            try await api.requestVoid(.delete, path: "/api/envelope-categories/\(id)", authenticated: true)
            categories.removeAll { $0.id == id }
            envelopes.removeAll { $0.envelopeCategoryId == id }
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to delete category."
            return false
        }
    }

    // MARK: - Envelope CRUD

    func createEnvelope(name: String, categoryId: String, initialAllocation: Decimal) async -> Bool {
        errorMessage = nil
        let request = CreateEnvelopeRequest(
            name: name,
            allocatedBalance: initialAllocation,
            envelopeCategoryId: categoryId
        )

        do {
            let newEnvelope: EnvelopeResponse = try await api.request(
                .post, path: "/api/envelopes", body: request, authenticated: true
            )
            envelopes.append(newEnvelope)
            // Reload month data to get the new allocation
            await loadMonthData()
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to create envelope."
            return false
        }
    }

    func deleteEnvelope(_ envelope: EnvelopeResponse) async -> Bool {
        guard let id = envelope.id else { return false }
        errorMessage = nil

        do {
            try await api.requestVoid(.delete, path: "/api/envelopes/\(id)", authenticated: true)
            envelopes.removeAll { $0.id == id }
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to delete envelope."
            return false
        }
    }

    func updateEnvelope(
        _ envelope: EnvelopeResponse,
        name: String? = nil,
        goalType: GoalType? = nil,
        goalAmount: Decimal? = nil,
        monthlyGoalTarget: Decimal? = nil,
        goalTargetDate: String? = nil,
        clearGoal: Bool = false
    ) async -> Bool {
        guard let id = envelope.id else { return false }
        errorMessage = nil

        // Build the full DTO for PUT (backend expects full EnvelopeDTO)
        let body = EnvelopeResponse(
            id: envelope.id,
            appUserId: envelope.appUserId,
            envelopeCategoryId: envelope.envelopeCategoryId,
            name: name ?? envelope.name,
            allocatedBalance: envelope.allocatedBalance,
            envelopeType: envelope.envelopeType,
            linkedAccountId: envelope.linkedAccountId,
            goalAmount: clearGoal ? nil : (goalAmount ?? envelope.goalAmount),
            monthlyGoalTarget: clearGoal ? nil : (monthlyGoalTarget ?? envelope.monthlyGoalTarget),
            goalTargetDate: clearGoal ? nil : (goalTargetDate ?? envelope.goalTargetDate),
            goalType: clearGoal ? nil : (goalType ?? envelope.goalType),
            createdAt: envelope.createdAt
        )

        do {
            let updated: EnvelopeResponse = try await api.request(
                .put, path: "/api/envelopes/\(id)", body: body, authenticated: true
            )
            if let index = envelopes.firstIndex(where: { $0.id == id }) {
                envelopes[index] = updated
            }
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to update envelope."
            return false
        }
    }

    // MARK: - CC Payment Helpers

    /// Look up the linked credit card's current balance (debt) for a CC Payment envelope.
    func cardBalance(for envelope: EnvelopeResponse, accounts: [BankAccountResponse]) -> Decimal {
        guard envelope.isCCPayment, let linkedId = envelope.linkedAccountId else { return Decimal.zero }
        return accounts.first { $0.id == linkedId }?.currentBalance ?? Decimal.zero
    }

    /// Compute the effective funding for a CC Payment envelope, accounting for
    /// overspent source envelopes.
    ///
    /// When a CC purchase is assigned to a regular envelope, the backend auto-moves
    /// the full purchase amount to the CC Payment envelope's allocation, regardless
    /// of whether the source envelope has enough allocated. If the source envelope
    /// is later reduced (or was never fully funded), the CC Payment envelope's raw
    /// `allocatedBalance` overstates how much is actually backed.
    ///
    /// This method subtracts the shortfall from overspent source envelopes,
    /// giving CC spending priority over cash spending (YNAB model).
    func ccEffectiveFunding(
        for envelope: EnvelopeResponse,
        accounts: [BankAccountResponse],
        transactions: [TransactionResponse]
    ) -> Decimal {
        guard envelope.isCCPayment, let ccAccountId = envelope.linkedAccountId else {
            return envelope.allocatedBalance
        }

        // If no transactions loaded yet, fall back to raw allocation
        guard !transactions.isEmpty else { return envelope.allocatedBalance }

        let shortfall = ccSourceShortfall(
            ccAccountId: ccAccountId,
            accounts: accounts,
            transactions: transactions
        )

        return envelope.allocatedBalance - shortfall
    }

    /// Coverage percent: how much of the card's debt is covered by effective funding (0→1).
    func ccCoveragePercent(
        for envelope: EnvelopeResponse,
        accounts: [BankAccountResponse],
        transactions: [TransactionResponse] = []
    ) -> Double {
        let debt = cardBalance(for: envelope, accounts: accounts)
        guard debt > 0 else { return 1.0 }
        let effective = ccEffectiveFunding(for: envelope, accounts: accounts, transactions: transactions)
        return max(0, min(1.0, NSDecimalNumber(decimal: effective / debt).doubleValue))
    }

    /// Whether a CC Payment envelope is underfunded (debt exceeds effective funding).
    func isUnderfunded(
        _ envelope: EnvelopeResponse,
        accounts: [BankAccountResponse],
        transactions: [TransactionResponse] = []
    ) -> Bool {
        if envelope.isCCPayment {
            let debt = cardBalance(for: envelope, accounts: accounts)
            let effective = ccEffectiveFunding(for: envelope, accounts: accounts, transactions: transactions)
            return debt > effective
        }
        return remaining(for: envelope) < 0
    }

    /// Total credit card debt across all CC Payment envelopes in a category.
    func ccCategoryTotalDebt(categoryId: String, accounts: [BankAccountResponse]) -> Decimal {
        let categoryEnvelopes = envelopesByCategory[categoryId] ?? []
        return categoryEnvelopes.reduce(Decimal.zero) { $0 + cardBalance(for: $1, accounts: accounts) }
    }

    /// Total effective funding across all CC Payment envelopes in a category.
    func ccCategoryTotalFunded(
        categoryId: String,
        accounts: [BankAccountResponse] = [],
        transactions: [TransactionResponse] = []
    ) -> Decimal {
        let categoryEnvelopes = envelopesByCategory[categoryId] ?? []
        return categoryEnvelopes.reduce(Decimal.zero) { sum, env in
            sum + ccEffectiveFunding(for: env, accounts: accounts, transactions: transactions)
        }
    }

    // MARK: - CC Source Shortfall (Private)

    /// Compute the funding shortfall from overspent source envelopes for a given CC account.
    ///
    /// For each regular envelope that has CC purchase transactions on the given card:
    /// - Compute the total CC spending (all cards) from that envelope
    /// - If total CC spending exceeds the envelope's allocation, CC spending is underfunded
    /// - Attribute the shortfall proportionally to this card
    ///
    /// CC spending gets priority over cash spending: an envelope's allocation covers
    /// CC purchases first, then any remainder covers cash. This matches YNAB behavior.
    private func ccSourceShortfall(
        ccAccountId: String,
        accounts: [BankAccountResponse],
        transactions: [TransactionResponse]
    ) -> Decimal {
        let ccAccountIds = Set(accounts.filter { $0.resolvedType.isCreditCard }.compactMap(\.id))
        let ccPaymentEnvelopeIds = Set(envelopes.filter(\.isCCPayment).compactMap(\.id))

        // Group CC purchase transactions by source envelope
        var totalCCSpendPerEnvelope: [String: Decimal] = [:]
        var thisCardSpendPerEnvelope: [String: Decimal] = [:]

        for txn in transactions {
            guard let bankId = txn.bankAccountId,
                  let envId = txn.envelopeId,
                  ccAccountIds.contains(bankId),
                  txn.amount < 0, // purchases only
                  !ccPaymentEnvelopeIds.contains(envId) // not CC Payment envelopes
            else { continue }

            let absAmt: Decimal = -txn.amount
            totalCCSpendPerEnvelope[envId, default: .zero] += absAmt
            if bankId == ccAccountId {
                thisCardSpendPerEnvelope[envId, default: .zero] += absAmt
            }
        }

        // Compute shortfall per source envelope, attributed to this card
        var totalShortfall: Decimal = .zero

        for (envId, thisCardSpend) in thisCardSpendPerEnvelope where thisCardSpend > 0 {
            guard let sourceEnvelope = envelopes.first(where: { $0.id == envId }) else { continue }

            let allCCSpend = totalCCSpendPerEnvelope[envId] ?? thisCardSpend
            // CC spending gets priority: shortfall only when CC spend exceeds allocation
            let envelopeShortfall = max(.zero, allCCSpend - sourceEnvelope.allocatedBalance)
            guard envelopeShortfall > 0 else { continue }

            // Attribute proportionally to this card
            let proportion = thisCardSpend / allCCSpend
            totalShortfall += envelopeShortfall * proportion
        }

        return totalShortfall
    }

    // MARK: - Allocation

    func setAllocation(for envelope: EnvelopeResponse, amount: Decimal) async -> Bool {
        guard let id = envelope.id else { return false }
        errorMessage = nil

        let request = SetAllocationRequest(amount: amount)

        do {
            let _: EnvelopeAllocationResponse = try await api.request(
                .put,
                path: "/api/envelopes/\(id)/allocation",
                body: request,
                queryItems: [URLQueryItem(name: "month", value: viewedMonthParam)],
                authenticated: true
            )
            // Reload everything to get updated allocatedBalance + month allocations
            async let envelopesReq: [EnvelopeResponse] = api.request(
                .get, path: "/api/envelopes", authenticated: true
            )
            async let allocReq: [EnvelopeAllocationResponse] = api.request(
                .get,
                path: "/api/envelopes/allocations",
                queryItems: [URLQueryItem(name: "month", value: viewedMonthParam)],
                authenticated: true
            )
            envelopes = try await envelopesReq
            monthlyAllocations = try await allocReq
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to update allocation."
            return false
        }
    }
}
