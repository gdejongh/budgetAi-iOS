//
//  TransactionService.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class TransactionService {
    // MARK: - State

    var transactions: [TransactionResponse] = []
    var isLoading = false
    var errorMessage: String?

    /// Current search text
    var searchText = ""

    /// Active sort field
    var sortField: SortField = .date

    /// Sort ascending
    var sortAscending = false

    /// Optional account filter
    var filterAccountId: String?

    /// Optional envelope filter
    var filterEnvelopeId: String?

    // MARK: - Clear Data

    /// Resets all state. Called on logout to prevent stale cross-user data.
    func clearData() {
        transactions = []
        isLoading = false
        errorMessage = nil
        searchText = ""
        filterAccountId = nil
        filterEnvelopeId = nil
    }

    // MARK: - Sort Options

    enum SortField: String, CaseIterable {
        case date = "Date"
        case amount = "Amount"
        case merchant = "Merchant"
    }

    // MARK: - Computed Properties

    /// Transactions count
    var transactionCount: Int { transactions.count }

    /// Filtered and sorted transactions
    var displayTransactions: [TransactionResponse] {
        var result = transactions

        // Account filter
        if let accountId = filterAccountId {
            result = result.filter { $0.bankAccountId == accountId }
        }

        // Envelope filter
        if let envelopeId = filterEnvelopeId {
            result = result.filter { $0.envelopeId == envelopeId }
        }

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { txn in
                (txn.merchantName?.lowercased().contains(query) ?? false) ||
                (txn.description?.lowercased().contains(query) ?? false)
            }
        }

        // Sort
        result.sort { a, b in
            let comparison: ComparisonResult
            switch sortField {
            case .date:
                let dateA = a.transactionDate ?? ""
                let dateB = b.transactionDate ?? ""
                let dateComparison = dateA.compare(dateB)
                if dateComparison != .orderedSame {
                    comparison = dateComparison
                } else {
                    // Use createdAt as tiebreaker for same-day transactions
                    let createdA = a.createdAt ?? ""
                    let createdB = b.createdAt ?? ""
                    comparison = createdA.compare(createdB)
                }
            case .amount:
                if a.amount == b.amount { comparison = .orderedSame }
                else if a.amount < b.amount { comparison = .orderedAscending }
                else { comparison = .orderedDescending }
            case .merchant:
                comparison = a.displayTitle.localizedCaseInsensitiveCompare(b.displayTitle)
            }
            return sortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
        }

        return result
    }

    /// Total income for displayed transactions
    var totalIncome: Decimal {
        displayTransactions
            .filter { $0.amount > 0 }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Total expenses for displayed transactions (absolute value)
    var totalExpenses: Decimal {
        let sum = displayTransactions
            .filter { $0.amount < 0 }
            .reduce(Decimal.zero) { $0 + $1.amount }
        return sum < 0 ? -sum : sum
    }

    // MARK: - Dependencies

    private let api: APIClient

    // MARK: - Init

    init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: - Fetch Transactions

    func fetchTransactions() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [TransactionResponse] = try await api.request(
                .get,
                path: "/api/transactions",
                authenticated: true
            )
            transactions = response
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to load transactions."
        }

        isLoading = false
    }

    /// Fetch transactions for a specific account
    func fetchByAccount(_ accountId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [TransactionResponse] = try await api.request(
                .get,
                path: "/api/transactions/by-account/\(accountId)",
                authenticated: true
            )
            transactions = response
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to load transactions."
        }

        isLoading = false
    }

    /// Fetch transactions for a specific envelope
    func fetchByEnvelope(_ envelopeId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [TransactionResponse] = try await api.request(
                .get,
                path: "/api/transactions/by-envelope/\(envelopeId)",
                authenticated: true
            )
            transactions = response
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to load transactions."
        }

        isLoading = false
    }

    /// Fetch transactions by date range
    func fetchByDateRange(start: String, end: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [TransactionResponse] = try await api.request(
                .get,
                path: "/api/transactions/by-date-range",
                queryItems: [
                    URLQueryItem(name: "startDate", value: start),
                    URLQueryItem(name: "endDate", value: end)
                ],
                authenticated: true
            )
            transactions = response
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to load transactions."
        }

        isLoading = false
    }

    // MARK: - Create Transaction

    func createTransaction(
        bankAccountId: String,
        envelopeId: String?,
        amount: Decimal,
        description: String?,
        merchantName: String?,
        transactionDate: String
    ) async -> Bool {
        errorMessage = nil

        let request = CreateTransactionRequest(
            bankAccountId: bankAccountId,
            envelopeId: envelopeId,
            amount: amount,
            description: description,
            transactionDate: transactionDate,
            merchantName: merchantName
        )

        do {
            let newTxn: TransactionResponse = try await api.request(
                .post,
                path: "/api/transactions",
                body: request,
                authenticated: true
            )
            transactions.insert(newTxn, at: 0)
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to create transaction."
            return false
        }
    }

    // MARK: - Update Transaction

    func updateTransaction(
        _ transaction: TransactionResponse,
        bankAccountId: String,
        envelopeId: String?,
        amount: Decimal,
        description: String?,
        merchantName: String?,
        transactionDate: String
    ) async -> Bool {
        guard let id = transaction.id, let appUserId = transaction.appUserId else { return false }
        errorMessage = nil

        let request = UpdateTransactionRequest(
            id: id,
            appUserId: appUserId,
            bankAccountId: bankAccountId,
            envelopeId: envelopeId,
            amount: amount,
            description: description,
            transactionDate: transactionDate,
            merchantName: merchantName
        )

        do {
            let updated: TransactionResponse = try await api.request(
                .put,
                path: "/api/transactions/\(id)",
                body: request,
                authenticated: true
            )
            if let index = transactions.firstIndex(where: { $0.id == id }) {
                transactions[index] = updated
            }
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to update transaction."
            return false
        }
    }

    // MARK: - Delete Transaction

    func deleteTransaction(_ transaction: TransactionResponse) async -> Bool {
        guard let id = transaction.id else { return false }
        errorMessage = nil

        do {
            try await api.requestVoid(
                .delete,
                path: "/api/transactions/\(id)",
                authenticated: true
            )
            transactions.removeAll { $0.id == id }
            // Also remove linked transaction if it existed locally
            if let linkedId = transaction.linkedTransactionId {
                transactions.removeAll { $0.id == linkedId }
            }
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to delete transaction."
            return false
        }
    }

    // MARK: - CC Payment

    func createCCPayment(
        bankAccountId: String,
        creditCardId: String,
        amount: Decimal,
        description: String?,
        transactionDate: String
    ) async -> Bool {
        errorMessage = nil

        let request = CCPaymentRequest(
            bankAccountId: bankAccountId,
            creditCardId: creditCardId,
            amount: amount,
            description: description,
            transactionDate: transactionDate
        )

        do {
            let newTxn: TransactionResponse = try await api.request(
                .post,
                path: "/api/transactions/cc-payment",
                body: request,
                authenticated: true
            )
            transactions.insert(newTxn, at: 0)
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to create CC payment."
            return false
        }
    }

    // MARK: - Transfer

    func createTransfer(
        sourceAccountId: String,
        destinationAccountId: String,
        amount: Decimal,
        merchantName: String?,
        description: String?,
        transactionDate: String
    ) async -> Bool {
        errorMessage = nil

        let request = TransferRequest(
            sourceAccountId: sourceAccountId,
            destinationAccountId: destinationAccountId,
            amount: amount,
            merchantName: merchantName,
            description: description,
            transactionDate: transactionDate
        )

        do {
            let newTxns: [TransactionResponse] = try await api.request(
                .post,
                path: "/api/transactions/transfer",
                body: request,
                authenticated: true
            )
            transactions.insert(contentsOf: newTxns, at: 0)
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to create transfer."
            return false
        }
    }

    // MARK: - Helpers

    /// Reset filters
    func clearFilters() {
        searchText = ""
        filterAccountId = nil
        filterEnvelopeId = nil
    }
}
