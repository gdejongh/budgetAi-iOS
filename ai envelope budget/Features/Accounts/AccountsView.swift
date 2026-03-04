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
    @State private var showCreateSheet = false
    @State private var showPlaidMapping = false
    @State private var plaidLinkResult: PlaidLinkResult?
    @State private var isConnectingBank = false

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
                    VStack(spacing: 12) {
                        Button("Connect Bank", systemImage: "link.circle.fill") {
                            Task { await connectBank() }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Add Manually", systemImage: "plus.circle.fill") {
                            showCreateSheet = true
                        }
                        .buttonStyle(.bordered)
                    }
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
            if accountService.accounts.isEmpty {
                await accountService.fetchAccounts()
            }
            if plaidService.plaidItems.isEmpty {
                await plaidService.fetchPlaidItems()
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

            // Plaid Connections Section
            PlaidConnectionsSection()
        }
        .listStyle(.insetGrouped)
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
            .environment(PlaidService())
            .environment(AccountService())
    }
}
