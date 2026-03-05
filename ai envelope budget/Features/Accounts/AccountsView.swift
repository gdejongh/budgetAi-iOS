//
//  AccountsView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct AccountsView: View {
    @Environment(AccountService.self) private var accountService
    @Environment(PlaidService.self) private var plaidService
    @Environment(DataRefreshService.self) private var dataRefreshService
    @State private var showCreateSheet = false
    @State private var showPlaidMapping = false
    @State private var plaidLinkResult: PlaidLinkResult?
    @State private var isConnectingBank = false
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
                    actionLabel: "Connect Bank"
                ) {
                    Task { await connectBank() }
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
                        Task { await connectBank() }
                    } label: {
                        Label("Connect Bank", systemImage: "link.circle.fill")
                    }

                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("Add Manually", systemImage: "plus.circle")
                    }
                } label: {
                    if isConnectingBank {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateAccountSheet()
        }
        .sheet(isPresented: $showPlaidMapping) {
            if let result = plaidLinkResult {
                PlaidAccountMappingSheet(linkResult: result)
            }
        }
        .refreshable {
            await accountService.fetchAccounts()
            await plaidService.fetchPlaidItems()
        }
        .navigationDestination(for: String.self) { accountId in
            AccountDetailView(accountId: accountId)
        }
        .task {
            await accountService.fetchAccounts()
            await plaidService.fetchPlaidItems()
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
                    }
                } header: {
                    Text("Credit Cards")
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            // Plaid Connections Section
            PlaidConnectionsSection()
        }
        .brandListStyle()
        .onAppear { hasAppeared = true }
    }

    // MARK: - Actions

    private func connectBank() async {
        isConnectingBank = true
        do {
            let result = try await plaidService.openPlaidLink()
            plaidLinkResult = result
            showPlaidMapping = true
        } catch let error as PlaidLinkError where error.errorDescription == "PLAID_LINK_DISMISSED" {
            // User dismissed — not an error
        } catch {
            // Error is already captured in plaidService.errorMessage
        }
        isConnectingBank = false
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
            .environment(PlaidService())
            .environment(AccountService())
            .environment(DataRefreshService(accountService: AccountService(), envelopeService: EnvelopeService(), transactionService: TransactionService()))
    }
}
