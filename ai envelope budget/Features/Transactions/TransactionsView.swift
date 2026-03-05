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
    @Environment(DataRefreshService.self) private var dataRefreshService

    @State private var showCreateTransaction = false
    @State private var showTransfer = false
    @State private var showCCPayment: BankAccountResponse?
    @State private var editTransaction: TransactionResponse?
    @State private var deleteTransaction: TransactionResponse?
    @State private var hasAppeared = false

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
        Group {
            @Bindable var service = transactionService
            if transactionService.isLoading && transactionService.transactions.isEmpty {
                ProgressView()
            } else if transactionService.transactions.isEmpty && transactionService.searchText.isEmpty {
                EmptyStateView(
                    icon: "arrow.left.arrow.right.circle.fill",
                    heading: "No Transactions Yet",
                    body: "Add your first transaction to start tracking spending.",
                    actionLabel: "Add Transaction"
                ) {
                    showCreateTransaction = true
                }
            } else {
                transactionsList
            }
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: searchTextBinding, prompt: "Search transactions")
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
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(TransactionService.SortField.allCases, id: \.self) { field in
                        Button {
                            transactionService.sortField = field
                        } label: {
                            if transactionService.sortField == field {
                                Label(field.rawValue, systemImage: "checkmark")
                            } else {
                                Text(field.rawValue)
                            }
                        }
                    }
                    Divider()
                    Button {
                        transactionService.sortAscending.toggle()
                    } label: {
                        Label(
                            transactionService.sortAscending ? "Descending" : "Ascending",
                            systemImage: transactionService.sortAscending ? "arrow.down" : "arrow.up"
                        )
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
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
                        await dataRefreshService.refreshAfterTransactionChange()
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
            if accountService.accounts.isEmpty {
                await accountService.fetchAccounts()
            }
            if envelopeService.envelopes.isEmpty {
                await envelopeService.loadAll()
            }
        }
    }

    /// Binding to transactionService.searchText (needs @Bindable in local scope for .searchable)
    private var searchTextBinding: Binding<String> {
        Binding(
            get: { transactionService.searchText },
            set: { transactionService.searchText = $0 }
        )
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        List {
            // Summary
            Section {
                HStack(spacing: AppDesign.paddingLg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(transactionService.totalIncome.asCurrency())
                            .font(.appBody)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.success)
                        Text("Income")
                            .font(.appCaption)
                            .foregroundStyle(Color.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(transactionService.totalExpenses.asCurrency())
                            .font(.appBody)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.danger)
                        Text("Expenses")
                            .font(.appCaption)
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    Text("\(transactionService.displayTransactions.count) txns")
                        .font(.appCaption)
                        .foregroundStyle(Color.textMuted)
                }
            }
            .staggeredFadeIn(index: 0, isVisible: hasAppeared)

            // Error banner
            if let error = transactionService.errorMessage {
                Section {
                    ErrorBannerView(message: error) {
                        await transactionService.fetchTransactions()
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Transactions
            let displayed = transactionService.displayTransactions
            if displayed.isEmpty {
                ContentUnavailableView.search
            } else {
                Section {
                    ForEach(displayed) { txn in
                        Button {
                            editTransaction = txn
                        } label: {
                            TransactionCardView(
                                transaction: txn,
                                accountName: txn.bankAccountId.flatMap { accountMap[$0] },
                                envelopeName: txn.envelopeId.flatMap { envelopeMap[$0] }
                            )
                        }
                        .buttonStyle(HighlightButtonStyle())
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteTransaction = txn
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                editTransaction = txn
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.warning)
                        }
                    }
                }
            }
        }
        .brandListStyle()
        .onAppear { hasAppeared = true }
    }
}

// MARK: - Highlight Button Style

private struct HighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Identifiable Wrappers

private struct IdentifiableAccount: Identifiable {
    let account: BankAccountResponse
    var id: String { account.id ?? UUID().uuidString }
}

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
            .environment(DataRefreshService(accountService: AccountService(), envelopeService: EnvelopeService(), transactionService: TransactionService()))
    }
}
