//
//  DashboardView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct DashboardView: View {
    @Environment(AuthService.self) private var authService
    @Environment(AccountService.self) private var accountService
    @Environment(EnvelopeService.self) private var envelopeService
    @Environment(TransactionService.self) private var transactionService

    @Binding var selectedTab: AppTab

    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading && accountService.accounts.isEmpty {
                ProgressView("Loading…")
                    .controlSize(.large)
            } else {
                List {
                    // Welcome header
                    Section {
                        if let email = authService.userEmail {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Welcome")
                    }

                    // Account Summary
                    if !accountService.accounts.isEmpty {
                        Section("Net Worth") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(accountService.netWorth.asCurrency())
                                    .font(.title.bold())
                                    .fontDesign(.rounded)
                                    .foregroundStyle(accountService.netWorth >= 0 ? Color.success : Color.danger)
                                    .accessibilityLabel(accountService.netWorth.asCurrencyAccessibilityLabel())

                                HStack(spacing: AppDesign.paddingLg) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(accountService.totalBankBalance.asCurrency())
                                            .font(.subheadline.weight(.semibold))
                                            .fontDesign(.rounded)
                                            .foregroundStyle(Color.success)
                                        Text("\(accountService.bankAccounts.count) Bank")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }

                                    if !accountService.creditCards.isEmpty {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(accountService.totalCreditCardDebt.asCurrency())
                                                .font(.subheadline.weight(.semibold))
                                                .fontDesign(.rounded)
                                                .foregroundStyle(Color.warning)
                                            Text("\(accountService.creditCards.count) Credit")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // Error banners
                    if let error = accountService.errorMessage {
                        Section {
                            ErrorBannerView(message: error) {
                                await accountService.fetchAccounts()
                            }
                        }
                    }

                    // Quick navigation cards
                    Section("Quick Access") {
                        Button {
                            selectedTab = .accounts
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Accounts")
                                        .font(.headline)
                                    Text(accountService.accounts.isEmpty
                                         ? "Add your first account"
                                         : "\(accountService.accounts.count) account\(accountService.accounts.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "building.columns.fill")
                                    .foregroundStyle(.tint)
                            }
                        }

                        Button {
                            selectedTab = .envelopes
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Envelopes")
                                        .font(.headline)
                                    Text(envelopeService.envelopes.isEmpty
                                         ? "Create your first envelope"
                                         : "\(envelopeService.envelopeCount) envelope\(envelopeService.envelopeCount == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "envelope.open.fill")
                                    .foregroundStyle(.tint)
                            }
                        }

                        Button {
                            selectedTab = .transactions
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Transactions")
                                        .font(.headline)
                                    Text(transactionService.transactions.isEmpty
                                         ? "Add your first transaction"
                                         : "\(transactionService.transactionCount) transaction\(transactionService.transactionCount == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "arrow.left.arrow.right")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }

                    // Sign out
                    Section {
                        Button(role: .destructive) {
                            Task { await authService.logout() }
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await loadAllData()
        }
        .task {
            await loadAllData()
            isLoading = false
        }
    }

    private func loadAllData() async {
        async let accounts: () = accountService.fetchAccounts()
        async let envelopes: () = envelopeService.loadAll()
        async let transactions: () = transactionService.fetchTransactions()
        _ = await (accounts, envelopes, transactions)
    }
}

#Preview {
    NavigationStack {
        DashboardView(selectedTab: .constant(.dashboard))
            .environment(AuthService())
            .environment(AccountService())
            .environment(EnvelopeService())
            .environment(TransactionService())
    }
}
