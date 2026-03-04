//
//  TransactionsView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct TransactionsView: View {
    @Environment(TransactionService.self) private var transactionService
    @Environment(AccountService.self) private var accountService
    @Environment(EnvelopeService.self) private var envelopeService

    @State private var showCreateTransaction = false
    @State private var showTransfer = false
    @State private var showCCPayment: BankAccountResponse?
    @State private var editTransaction: TransactionResponse?
    @State private var deleteTransaction: TransactionResponse?

    /// Account name lookup
    private var accountMap: [String: String] {
        Dictionary(uniqueKeysWithValues: accountService.accounts.compactMap { a in
            guard let id = a.id else { return nil }
            return (id, a.name)
        })
    }

    /// Envelope name lookup
    private var envelopeMap: [String: String] {
        Dictionary(uniqueKeysWithValues: envelopeService.envelopes.compactMap { e in
            guard let id = e.id else { return nil }
            return (id, e.name)
        })
    }

    var body: some View {
        ZStack {
            Color.bgPrimary
                .ignoresSafeArea()

            if transactionService.isLoading && transactionService.transactions.isEmpty {
                loadingView
            } else if transactionService.transactions.isEmpty && transactionService.searchText.isEmpty {
                emptyStateView
            } else {
                transactionsList
            }
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showCreateTransaction = true
                    } label: {
                        Label("New Transaction", systemImage: "plus.circle")
                    }

                    Button {
                        showTransfer = true
                    } label: {
                        Label("Transfer", systemImage: "arrow.triangle.swap")
                    }

                    if !accountService.creditCards.isEmpty {
                        Menu("CC Payment") {
                            ForEach(accountService.creditCards) { cc in
                                Button {
                                    showCCPayment = cc
                                } label: {
                                    Label(cc.name, systemImage: "creditcard.fill")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(LinearGradient.brand)
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showCreateTransaction) {
            CreateTransactionSheet()
        }
        .sheet(isPresented: $showTransfer) {
            TransferSheet()
        }
        .sheet(item: Binding(
            get: { showCCPayment.map { IdentifiableAccount(account: $0) } },
            set: { showCCPayment = $0?.account }
        )) { wrapper in
            CCPaymentSheet(creditCard: wrapper.account)
        }
        .sheet(item: Binding(
            get: { editTransaction.map { IdentifiableTransaction(transaction: $0) } },
            set: { editTransaction = $0?.transaction }
        )) { wrapper in
            EditTransactionSheet(transaction: wrapper.transaction)
        }
        .confirmationDialog(
            "Delete Transaction",
            isPresented: Binding(
                get: { deleteTransaction != nil },
                set: { if !$0 { deleteTransaction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let txn = deleteTransaction {
                Button("Delete", role: .destructive) {
                    Task {
                        _ = await transactionService.deleteTransaction(txn)
                        await accountService.fetchAccounts()
                    }
                }
            }
            Button("Cancel", role: .cancel) { deleteTransaction = nil }
        } message: {
            Text("This transaction will be permanently deleted. This cannot be undone.")
        }
        .refreshable {
            await transactionService.fetchTransactions()
        }
        .task {
            if transactionService.transactions.isEmpty {
                await transactionService.fetchTransactions()
            }
            // Ensure we have accounts & envelopes for name lookups
            if accountService.accounts.isEmpty {
                await accountService.fetchAccounts()
            }
            if envelopeService.envelopes.isEmpty {
                await envelopeService.loadAll()
            }
        }
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        ScrollView {
            VStack(spacing: AppDesign.paddingLg) {
                // Search bar
                searchBar

                // Summary
                summaryRow

                // Sort controls
                sortControls

                // Error banner
                if let error = transactionService.errorMessage {
                    errorBanner(error)
                }

                // Transactions
                let displayed = transactionService.displayTransactions
                if displayed.isEmpty {
                    noResultsView
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(displayed) { txn in
                            TransactionCardView(
                                transaction: txn,
                                accountName: txn.bankAccountId.flatMap { accountMap[$0] },
                                envelopeName: txn.envelopeId.flatMap { envelopeMap[$0] }
                            )
                            .contextMenu {
                                if txn.isEditable {
                                    Button {
                                        editTransaction = txn
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                }

                                Button(role: .destructive) {
                                    deleteTransaction = txn
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppDesign.paddingLg)
            .padding(.vertical, AppDesign.paddingMd)
        }
    }

    // MARK: - Search Bar

    @MainActor
    private var searchBar: some View {
        @Bindable var service = transactionService
        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textMuted)

            TextField("Search transactions…", text: $service.searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.textPrimary)

            if !transactionService.searchText.isEmpty {
                Button {
                    transactionService.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textMuted)
                }
            }
        }
        .padding(AppDesign.paddingSm + 4)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                .fill(Color.bgInput)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                        .stroke(Color.borderSubtle, lineWidth: 1)
                )
        )
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: AppDesign.paddingLg) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatCurrency(transactionService.totalIncome))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.success)
                Text("Income")
                    .font(.caption2)
                    .foregroundStyle(Color.textMuted)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(formatCurrency(transactionService.totalExpenses))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.danger)
                Text("Expenses")
                    .font(.caption2)
                    .foregroundStyle(Color.textMuted)
            }

            Spacer()

            Text("\(transactionService.displayTransactions.count) txns")
                .font(.caption)
                .foregroundStyle(Color.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.bgCardHover))
        }
        .padding(AppDesign.paddingSm + 4)
        .glassCard()
    }

    // MARK: - Sort Controls

    private var sortControls: some View {
        HStack(spacing: 8) {
            Text("Sort:")
                .font(.caption2)
                .foregroundStyle(Color.textMuted)

            ForEach(TransactionService.SortField.allCases, id: \.self) { field in
                sortChip(field)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    transactionService.sortAscending.toggle()
                }
            } label: {
                Image(systemName: transactionService.sortAscending ? "arrow.up" : "arrow.down")
                    .font(.caption)
                    .foregroundStyle(Color.accentCyan)
                    .padding(6)
                    .background(Circle().fill(Color.bgCardHover))
            }
        }
    }

    private func sortChip(_ field: TransactionService.SortField) -> some View {
        let isActive = transactionService.sortField == field
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                transactionService.sortField = field
            }
        } label: {
            Text(field.rawValue)
                .font(.caption)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundStyle(isActive ? Color.textPrimary : Color.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(isActive ? Color.bgCardHover : Color.clear)
                )
        }
    }

    // MARK: - Empty / No Results / Loading

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(LinearGradient.brand)
                .shadow(color: .accentCyan.opacity(0.3), radius: 16)

            VStack(spacing: 8) {
                Text("No Transactions Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)

                Text("Add your first transaction to start tracking spending.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                showCreateTransaction = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Transaction")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 32)
                .background(LinearGradient.brand)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd))
                .glowShadow()
            }
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundStyle(Color.textMuted)

            Text("No transactions match your search")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.vertical, 40)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.accentCyan)

            Text("Loading transactions…")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.danger)

            Text(message)
                .font(.caption)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Button {
                Task { await transactionService.fetchTransactions() }
            } label: {
                Text("Retry")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentCyan)
            }
        }
        .padding(AppDesign.paddingSm)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                .fill(Color.danger.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                        .stroke(Color.danger.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Identifiable Wrappers

/// Wrapper to make BankAccountResponse work with .sheet(item:)
private struct IdentifiableAccount: Identifiable {
    let account: BankAccountResponse
    var id: String { account.id ?? UUID().uuidString }
}

/// Wrapper to make TransactionResponse work with .sheet(item:)
private struct IdentifiableTransaction: Identifiable {
    let transaction: TransactionResponse
    var id: String { transaction.id ?? UUID().uuidString }
}

#Preview {
    NavigationStack {
        TransactionsView()
            .environment(TransactionService())
            .environment(AccountService())
            .environment(EnvelopeService())
    }
}
