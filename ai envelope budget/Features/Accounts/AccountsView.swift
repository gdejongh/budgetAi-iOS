//
//  AccountsView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct AccountsView: View {
    @Environment(AccountService.self) private var accountService
    @Environment(DataRefreshService.self) private var dataRefreshService
    @State private var showCreateSheet = false
    @State private var hasAppeared = false

    var body: some View {
        Group {
            if accountService.isLoading && accountService.accounts.isEmpty {
                ProgressView()
            } else if accountService.accounts.isEmpty {
                EmptyStateView(
                    icon: "building.columns.fill",
                    heading: "No Accounts Yet",
                    body: "Add a bank account or credit card to start tracking your finances.",
                    actionLabel: "Add Account"
                ) {
                    showCreateSheet = true
                }
            } else {
                accountsList
            }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("Add Manually", systemImage: "plus.circle")
                    }
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
            await accountService.fetchAccounts()
        }
    }

    // MARK: - Accounts List

    private var accountsList: some View {
        List {
            // Net Worth Summary
            Section {
                VStack(spacing: 8) {
                    Text("Net Worth")
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)

                    Text(accountService.netWorth.asCurrency())
                        .font(.appStatLarge)
                        .foregroundStyle(Color.textPrimary)

                    HStack(spacing: 24) {
                        summaryItem(
                            label: "Bank Accounts",
                            value: accountService.totalBankBalance.asCurrency(),
                            color: .success
                        )

                        if !accountService.creditCards.isEmpty {
                            summaryItem(
                                label: "Credit Cards",
                                value: accountService.totalCreditCardDebt.asCurrency(),
                                color: .warning
                            )
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
            }
            .staggeredFadeIn(index: 0, isVisible: hasAppeared)

            // Error banner
            if let error = accountService.errorMessage {
                ErrorBannerView(message: error) {
                    await dataRefreshService.refreshAll()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Bank Accounts Section
            if !accountService.bankAccounts.isEmpty {
                Section {
                    ForEach(accountService.bankAccounts, id: \.id) { account in
                        NavigationLink(value: account.id ?? "") {
                            AccountCardView(account: account)
                        }
                        .listRowInsets(EdgeInsets())
                        .brandRowBackground()
                    }
                } header: {
                    Text("Bank Accounts")
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            // Credit Cards Section
            if !accountService.creditCards.isEmpty {
                Section {
                    ForEach(accountService.creditCards, id: \.id) { account in
                        NavigationLink(value: account.id ?? "") {
                            AccountCardView(account: account)
                        }
                        .listRowInsets(EdgeInsets())
                        .brandRowBackground()
                    }
                } header: {
                    Text("Credit Cards")
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .brandListStyle()
        .onAppear { hasAppeared = true }
    }

    // MARK: - Helpers

    private func summaryItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.appBody)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        AccountsView()
            .environment(AccountService())
            .environment(DataRefreshService(accountService: AccountService(), envelopeService: EnvelopeService(), transactionService: TransactionService()))
    }
}
