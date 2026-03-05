//
//  AppleWalletService.swift
//  ai envelope budget
//
//  Created on 3/5/26.
//

import FinanceKit
import Foundation
import Observation

/// Manages Apple Wallet account discovery, linking, and automatic transaction
/// syncing via the FinanceKit framework. Follows the same @Observable pattern
/// as PlaidService and AccountService.
///
/// Key design decisions:
/// - Client-push: reads data on-device via FinanceKit, POSTs to existing backend endpoints
/// - Fully automatic sync on app launch/foreground with 5-minute throttle
/// - Deduplication by matching existing transactions on date + amount + merchant
/// - Duplicate prevention: blocks linking accounts already connected via Plaid
@Observable
@MainActor
final class AppleWalletService {
    // MARK: - State

    var linkedAccounts: [AppleWalletAccountLink] = []
    var authStatus: AppleWalletAuthStatus = .notDetermined
    var syncState: AppleWalletSyncState = .idle
    var discoveredAccounts: [DiscoveredAppleWalletAccount] = []
    var errorMessage: String?

    // MARK: - Dependencies

    private let api: APIClient
    private let store: FinanceStore

    // MARK: - Sync Throttle

    /// Minimum interval between automatic syncs (5 minutes)
    private static let syncThrottleInterval: TimeInterval = 300
    private var lastAutoSyncDate: Date?

    // MARK: - Init

    init(api: APIClient = .shared) {
        self.api = api
        self.store = FinanceStore.shared
        self.linkedAccounts = AppleWalletStorage.loadLinkedAccounts()
    }

    // MARK: - Clear Data

    /// Resets all state. Called on logout to prevent stale cross-user data.
    func clearData() {
        linkedAccounts = []
        discoveredAccounts = []
        authStatus = .notDetermined
        syncState = .idle
        errorMessage = nil
        lastAutoSyncDate = nil
        AppleWalletStorage.clearAll()
    }

    // MARK: - FinanceKit Availability

    /// Whether FinanceKit is available on this device
    static var isAvailable: Bool {
        FinanceStore.isDataAvailable(.financialData)
    }

    // MARK: - Authorization

    /// Check and update the current authorization status.
    func checkAuthorization() async {
        guard Self.isAvailable else {
            authStatus = .denied
            return
        }

        do {
            let authResult = try await store.requestAuthorization()
            switch authResult {
            case .authorized:
                authStatus = .authorized
            case .denied:
                authStatus = .denied
            case .notDetermined:
                authStatus = .notDetermined
            @unknown default:
                authStatus = .notDetermined
            }
        } catch {
            authStatus = .denied
            errorMessage = "Failed to authorize Apple Wallet access."
        }
    }

    /// Request authorization if not already determined.
    func requestAuthorization() async -> Bool {
        await checkAuthorization()
        return authStatus == .authorized
    }

    // MARK: - Account Discovery

    /// Discover Apple Wallet financial accounts via FinanceKit.
    /// Cross-references with existing app accounts to detect Plaid duplicates.
    func discoverAccounts(existingAccounts: [BankAccountResponse]) async {
        if authStatus != .authorized {
            await checkAuthorization()
            guard authStatus == .authorized else { return }
        }

        errorMessage = nil

        do {
            let query = AccountQuery()
            let financeAccounts = try await store.accounts(query: query)

            // Fetch balances for all accounts
            let balanceQuery = AccountBalanceQuery()
            let balances = try await store.accountBalances(query: balanceQuery)

            discoveredAccounts = financeAccounts.map { (account: Account) in
                let appType = self.mapAccountType(account)

                // Find balance for this account
                let balance = balances.first { $0.accountID == account.id }
                let balanceAmount = self.extractBalance(balance?.currentBalance)

                return DiscoveredAppleWalletAccount(
                    id: account.id.uuidString,
                    name: account.displayName,
                    institutionName: account.institutionName,
                    accountType: appType,
                    currentBalance: balanceAmount,
                    isAlreadyLinkedViaPlaid: self.isLinkedViaPlaid(
                        account, existingAccounts: existingAccounts
                    ),
                    isAlreadyLinkedViaWallet: self.linkedAccounts.contains {
                        $0.financeKitAccountId == account.id.uuidString
                    }
                )
            }
        } catch {
            errorMessage = "Failed to discover Apple Wallet accounts."
            discoveredAccounts = []
        }
    }

    // MARK: - Link Account

    /// Links a discovered Apple Wallet account by creating a backend BankAccount
    /// and persisting the local mapping.
    func linkAccount(
        _ discovered: DiscoveredAppleWalletAccount,
        customName: String? = nil,
        existingAccountId: String? = nil
    ) async -> Bool {
        errorMessage = nil

        let accountName = customName ?? discovered.name

        do {
            let bankAccountId: String

            if let existingId = existingAccountId {
                // Link to existing account
                bankAccountId = existingId
            } else {
                // Create new backend account
                let request = CreateBankAccountRequest(
                    name: accountName,
                    accountType: discovered.accountType,
                    currentBalance: discovered.currentBalance
                )

                let newAccount: BankAccountResponse = try await api.request(
                    .post,
                    path: "/api/bank-accounts",
                    body: request,
                    authenticated: true
                )

                guard let id = newAccount.id else {
                    errorMessage = "Failed to create account — missing ID."
                    return false
                }
                bankAccountId = id
            }

            // Persist local mapping
            let link = AppleWalletAccountLink(
                financeKitAccountId: discovered.id,
                bankAccountId: bankAccountId,
                accountName: accountName,
                accountType: discovered.accountType,
                institutionName: discovered.institutionName,
                linkedAt: Date(),
                lastSyncedAt: nil
            )
            linkedAccounts.append(link)
            AppleWalletStorage.saveLinkedAccounts(linkedAccounts)

            // Do initial sync for this account
            await syncAccount(link)

            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to link Apple Wallet account."
            return false
        }
    }

    // MARK: - Unlink Account

    /// Removes the local Apple Wallet link. Does NOT delete the backend account.
    func unlinkAccount(_ link: AppleWalletAccountLink) {
        linkedAccounts.removeAll { $0.financeKitAccountId == link.financeKitAccountId }
        AppleWalletStorage.saveLinkedAccounts(linkedAccounts)
    }

    // MARK: - Automatic Sync (App Lifecycle)

    /// Syncs all linked accounts if enough time has passed since the last sync.
    /// Called from RootView on app launch and foreground resume.
    func autoSyncIfNeeded() async {
        guard !linkedAccounts.isEmpty else { return }
        guard authStatus == .authorized || authStatus == .notDetermined else { return }

        // Check throttle
        if let lastSync = lastAutoSyncDate,
           Date().timeIntervalSince(lastSync) < Self.syncThrottleInterval {
            return
        }

        // Ensure authorized
        if authStatus == .notDetermined {
            await checkAuthorization()
            guard authStatus == .authorized else { return }
        }

        await syncAllLinkedAccounts()
    }

    // MARK: - Sync All Linked Accounts

    /// Syncs transactions and balances for all linked Apple Wallet accounts.
    func syncAllLinkedAccounts() async {
        guard !linkedAccounts.isEmpty else { return }

        syncState = .syncing
        errorMessage = nil
        var totalNewTransactions = 0

        for link in linkedAccounts {
            let newCount = await syncAccount(link)
            totalNewTransactions += newCount
        }

        lastAutoSyncDate = Date()
        syncState = .success(newTransactions: totalNewTransactions)

        // Auto-reset to idle after 3 seconds
        try? await Task.sleep(for: .seconds(3))
        if case .success = syncState {
            syncState = .idle
        }
    }

    // MARK: - Sync Single Account

    /// Syncs a single linked account. Returns the count of new transactions posted.
    @discardableResult
    private func syncAccount(_ link: AppleWalletAccountLink) async -> Int {
        do {
            // 1. Fetch transactions from FinanceKit since last sync
            let sinceDate = link.lastSyncedAt ?? link.linkedAt
            let transactions = try await fetchFinanceKitTransactions(
                accountId: link.financeKitAccountId,
                since: sinceDate
            )

            // 2. Fetch existing transactions from backend for dedup
            let existingTransactions: [TransactionResponse] = try await api.request(
                .get,
                path: "/api/transactions/by-account/\(link.bankAccountId)",
                authenticated: true
            )

            // 3. Deduplicate
            let newTransactions = deduplicateTransactions(
                financeKitTransactions: transactions,
                existingTransactions: existingTransactions,
                bankAccountId: link.bankAccountId
            )

            // 4. Post new transactions in batches
            var postedCount = 0
            let batchSize = 50
            for batchStart in stride(from: 0, to: newTransactions.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, newTransactions.count)
                let batch = Array(newTransactions[batchStart..<batchEnd])

                for request in batch {
                    do {
                        let _: TransactionResponse = try await api.request(
                            .post,
                            path: "/api/transactions",
                            body: request,
                            authenticated: true
                        )
                        postedCount += 1
                    } catch {
                        // Continue with remaining transactions on individual failure
                    }
                }
            }

            // 5. Sync balance
            await syncBalance(link)

            // 6. Update lastSyncedAt
            if let index = linkedAccounts.firstIndex(where: {
                $0.financeKitAccountId == link.financeKitAccountId
            }) {
                linkedAccounts[index].lastSyncedAt = Date()
                AppleWalletStorage.saveLinkedAccounts(linkedAccounts)
            }

            return postedCount

        } catch {
            // Non-fatal: log but don't fail the entire sync run
            return 0
        }
    }

    // MARK: - FinanceKit Data Fetching

    /// Fetches transactions from FinanceKit for a given account since a date.
    private nonisolated func fetchFinanceKitTransactions(
        accountId: String,
        since: Date
    ) async throws -> [FinanceKit.Transaction] {
        guard let uuid = UUID(uuidString: accountId) else { return [] }

        let sinceDate = since
        let query = TransactionQuery(
            sortDescriptors: [SortDescriptor(\FinanceKit.Transaction.transactionDate, order: .reverse)],
            predicate: #Predicate<FinanceKit.Transaction> { transaction in
                transaction.accountID == uuid && transaction.transactionDate >= sinceDate
            }
        )

        let store = FinanceStore.shared
        return try await store.transactions(query: query)
    }

    // MARK: - Balance Sync

    /// Updates the backend account balance from FinanceKit.
    private func syncBalance(_ link: AppleWalletAccountLink) async {
        do {
            guard let uuid = UUID(uuidString: link.financeKitAccountId) else { return }

            let balanceQuery = AccountBalanceQuery(
                predicate: #Predicate<AccountBalance> { balance in
                    balance.accountID == uuid
                }
            )
            let balances = try await store.accountBalances(query: balanceQuery)

            guard let accountBalance = balances.first else { return }

            let balance = extractBalance(accountBalance.currentBalance)
            let request = ReconcileBalanceRequest(targetBalance: balance)

            try await api.requestVoid(
                .post,
                path: "/api/bank-accounts/\(link.bankAccountId)/reconcile",
                body: request,
                authenticated: true
            )
        } catch {
            // Non-fatal — balance sync failure shouldn't block the rest
        }
    }

    // MARK: - Deduplication

    /// Filters out FinanceKit transactions that already exist in the backend.
    /// Matches on date + amount + merchant name to avoid re-posting.
    private nonisolated func deduplicateTransactions(
        financeKitTransactions: [FinanceKit.Transaction],
        existingTransactions: [TransactionResponse],
        bankAccountId: String
    ) -> [CreateTransactionRequest] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Build a set of existing transaction signatures for O(1) lookup
        let existingSignatures: Set<String> = Set(existingTransactions.compactMap { txn in
            guard let date = txn.transactionDate else { return nil }
            let amount = txn.amount
            let merchant = (txn.merchantName ?? txn.description ?? "").lowercased()
                .trimmingCharacters(in: CharacterSet.whitespaces)
            return "\(date)|\(amount)|\(merchant)"
        })

        var newRequests: [CreateTransactionRequest] = []

        for fkTxn in financeKitTransactions {
            let date = dateFormatter.string(from: fkTxn.transactionDate)
            let amount = mapTransactionAmount(fkTxn)
            let merchant = fkTxn.merchantName ?? fkTxn.transactionDescription
            let merchantNormalized = merchant.lowercased()
                .trimmingCharacters(in: CharacterSet.whitespaces)

            let signature = "\(date)|\(amount)|\(merchantNormalized)"

            if !existingSignatures.contains(signature) {
                let request = CreateTransactionRequest(
                    bankAccountId: bankAccountId,
                    envelopeId: nil,
                    amount: amount,
                    description: fkTxn.transactionDescription,
                    transactionDate: date,
                    merchantName: fkTxn.merchantName
                )
                newRequests.append(request)
            }
        }

        return newRequests
    }

    // MARK: - Mapping Helpers

    /// Maps a FinanceKit Account enum to the app's AccountType.
    /// Account is an enum with .asset(AssetAccount) and .liability(LiabilityAccount) cases.
    private func mapAccountType(_ account: Account) -> AccountType {
        switch account {
        case .liability:
            return .creditCard
        case .asset:
            // Apple Cash → checking, Apple Savings → savings
            if account.displayName.localizedCaseInsensitiveContains("savings") {
                return .savings
            }
            return .checking
        @unknown default:
            return .checking
        }
    }

    /// Extracts a Decimal balance from a FinanceKit CurrentBalance enum.
    /// CurrentBalance has cases: .available(Balance), .booked(Balance),
    /// .availableAndBooked(available: Balance, booked: Balance)
    private func extractBalance(_ currentBalance: CurrentBalance?) -> Decimal {
        guard let currentBalance else { return .zero }
        switch currentBalance {
        case .available(let balance):
            return balance.amount.amount
        case .booked(let balance):
            return balance.amount.amount
        case .availableAndBooked(let available, _):
            return available.amount.amount
        @unknown default:
            return .zero
        }
    }

    /// Maps a FinanceKit transaction amount to the app's sign convention.
    /// App convention: negative = expense, positive = income/refund.
    private nonisolated func mapTransactionAmount(_ transaction: FinanceKit.Transaction) -> Decimal {
        let rawAmount = transaction.transactionAmount.amount
        switch transaction.creditDebitIndicator {
        case .debit:
            // Expense → negative in our app
            return -abs(rawAmount)
        case .credit:
            // Income/refund → positive in our app
            return abs(rawAmount)
        @unknown default:
            return rawAmount
        }
    }

    /// Checks whether a FinanceKit account appears to already be linked via Plaid.
    /// Matches on institution name patterns (e.g., "Apple Card" / "Apple" institution).
    private func isLinkedViaPlaid(
        _ account: Account,
        existingAccounts: [BankAccountResponse]
    ) -> Bool {
        let fkName = account.displayName.lowercased()
        let fkInstitution = account.institutionName.lowercased()

        return existingAccounts.contains { existing in
            guard existing.isPlaidLinked else { return false }
            let existingName = existing.name.lowercased()
            let existingInstitution = (existing.institutionName ?? "").lowercased()

            // Match if institution + account name are very similar
            let institutionMatch = !fkInstitution.isEmpty && !existingInstitution.isEmpty
                && (fkInstitution.contains(existingInstitution)
                    || existingInstitution.contains(fkInstitution))

            let nameMatch = fkName.contains(existingName)
                || existingName.contains(fkName)

            return institutionMatch && nameMatch
        }
    }
}
