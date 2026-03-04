//
//  AccountsView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct AccountsView: View {
    @Environment(AccountService.self) private var accountService
    @State private var showCreateSheet = false

    var body: some View {
        Group {
            if accountService.isLoading && accountService.accounts.isEmpty {
                ProgressView()
            } else if accountService.accounts.isEmpty {
                ContentUnavailableView {
                    Label("No Accounts Yet", systemImage: "building.columns.fill")
                } description: {
                    Text("Add a bank account or credit card to start tracking your finances.")
                } actions: {
                    Button("Add Account", systemImage: "plus.circle.fill") {
                        showCreateSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                accountsList
            }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateAccountSheet()
        }
        .refreshable {
            await accountService.fetchAccounts()
        }
        .navigationDestination(for: String.self) { accountId in
            AccountDetailView(accountId: accountId)
        }
        .task {
            if accountService.accounts.isEmpty {
                await accountService.fetchAccounts()
            }
        }
    }

    // MARK: - Accounts List

    private var accountsList: some View {
        List {
            // Net Worth Summary
            Section {
                VStack(spacing: 8) {
                    Text("Net Worth")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(accountService.netWorth.asCurrency())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    HStack(spacing: 24) {
                        summaryItem(
                            label: "Bank Accounts",
                            value: accountService.totalBankBalance.asCurrency(),
                            color: .green
                        )

                        if !accountService.creditCards.isEmpty {
                            summaryItem(
                                label: "Credit Cards",
                                value: accountService.totalCreditCardDebt.asCurrency(),
                                color: .orange
                            )
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
            }

            // Error banner
            if let error = accountService.errorMessage {
                ErrorBannerView(message: error) {
                    await accountService.fetchAccounts()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Bank Accounts Section
            if !accountService.bankAccounts.isEmpty {
                Section("Bank Accounts") {
                    ForEach(accountService.bankAccounts, id: \.id) { account in
                        NavigationLink(value: account.id ?? "") {
                            AccountCardView(account: account)
                        }
                    }
                }
            }

            // Credit Cards Section
            if !accountService.creditCards.isEmpty {
                Section("Credit Cards") {
                    ForEach(accountService.creditCards, id: \.id) { account in
                        NavigationLink(value: account.id ?? "") {
                            AccountCardView(account: account)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Helpers

    private func summaryItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        AccountsView()
            .environment(AccountService())
    }
}
