//
//  DataRefreshService.swift
//  ai envelope budget
//
//  Created on 3/4/26.
//

import Foundation
import Observation

/// Centralized coordinator for cross-service data refreshes.
///
/// When a mutation in one service affects data in other services (e.g., creating
/// a transaction changes account balances and envelope spent totals), this service
/// ensures all affected services reload their data from the backend.
///
/// This avoids scattered, ad-hoc refresh calls in views and guarantees consistency.
@Observable
@MainActor
final class DataRefreshService {
    // MARK: - Dependencies

    private let accountService: AccountService
    private let envelopeService: EnvelopeService
    private let transactionService: TransactionService

    // MARK: - Init

    init(
        accountService: AccountService,
        envelopeService: EnvelopeService,
        transactionService: TransactionService
    ) {
        self.accountService = accountService
        self.envelopeService = envelopeService
        self.transactionService = transactionService
    }

    // MARK: - Refresh Strategies

    /// Refresh after a transaction is created, edited, or deleted.
    ///
    /// Transactions affect: account balances, envelope spent summaries,
    /// and (for CC transactions) CC Payment envelope allocations.
    func refreshAfterTransactionChange() async {
        async let accounts: () = accountService.fetchAccounts()
        async let envelopes: () = envelopeService.loadAll()
        _ = await (accounts, envelopes)
    }

    /// Refresh after a CC payment is made.
    ///
    /// CC payments affect both account balances (bank + CC) and
    /// CC Payment envelope allocations/spent summaries.
    func refreshAfterCCPayment() async {
        async let accounts: () = accountService.fetchAccounts()
        async let envelopes: () = envelopeService.loadAll()
        _ = await (accounts, envelopes)
    }

    /// Refresh after an account is created, edited, or deleted.
    ///
    /// Account changes can affect envelopes (CC account creation/deletion
    /// auto-manages CC Payment envelopes) and transactions (deletion cascades).
    func refreshAfterAccountChange() async {
        async let accounts: () = accountService.fetchAccounts()
        async let envelopes: () = envelopeService.loadAll()
        async let transactions: () = transactionService.fetchTransactions()
        _ = await (accounts, envelopes, transactions)
    }

    /// Refresh after an account balance is reconciled.
    ///
    /// Reconciliation creates a balancing transaction on the backend,
    /// so both transactions and envelopes may be affected.
    func refreshAfterReconcile() async {
        async let transactions: () = transactionService.fetchTransactions()
        async let envelopes: () = envelopeService.loadAll()
        _ = await (transactions, envelopes)
    }

    /// Refresh after an envelope allocation changes.
    ///
    /// Allocation changes can affect the accounts view if it displays
    /// envelope-related data (e.g., CC underfunded state uses envelope data).
    /// Account data doesn't change, but we refresh envelope data (already
    /// handled by EnvelopeService.setAllocation), so this is a no-op for now.
    /// Keeping the method for future use and consistency.
    func refreshAfterEnvelopeChange() async {
        // EnvelopeService already reloads its own data after allocation changes.
        // No cross-service impact currently.
    }

    /// Refresh after Apple Wallet sync completes.
    ///
    /// Apple Wallet sync creates transactions and reconciles balances,
    /// so all services need refreshing.
    func refreshAfterAppleWalletSync() async {
        async let accounts: () = accountService.fetchAccounts()
        async let envelopes: () = envelopeService.loadAll()
        async let transactions: () = transactionService.fetchTransactions()
        _ = await (accounts, envelopes, transactions)
    }

    /// Refresh all data across all services. Used for pull-to-refresh and
    /// initial loads.
    func refreshAll() async {
        async let accounts: () = accountService.fetchAccounts()
        async let envelopes: () = envelopeService.loadAll()
        async let transactions: () = transactionService.fetchTransactions()
        _ = await (accounts, envelopes, transactions)
    }
}
