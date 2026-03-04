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
    @Environment(AiAdviceService.self) private var aiAdviceService
    @Environment(DataRefreshService.self) private var dataRefreshService

    @Binding var selectedTab: AppTab

    @State private var isLoading = true
    @State private var hasAppeared = false

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
                                .font(.appSubheadline)
                                .foregroundStyle(Color.textSecondary)
                        }
                    } header: {
                        Text("Welcome")
                    }

                    // Account Summary
                    if !accountService.accounts.isEmpty {
                        Section("Net Worth") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(accountService.netWorth.asCurrency())
                                    .font(.appStatLarge)
                                    .headingTracking()
                                    .foregroundStyle(accountService.netWorth >= 0 ? Color.success : Color.danger)
                                    .contentTransition(.numericText())
                                    .accessibilityLabel(accountService.netWorth.asCurrencyAccessibilityLabel())

                                HStack(spacing: AppDesign.paddingLg) {
                                    StatCard(
                                        icon: "building.columns.fill",
                                        label: "\(accountService.bankAccounts.count) Bank",
                                        value: accountService.totalBankBalance.asCurrency(),
                                        iconColor: .success,
                                        valueColor: .success
                                    )

                                    if !accountService.creditCards.isEmpty {
                                        StatCard(
                                            icon: "creditcard.fill",
                                            label: "\(accountService.creditCards.count) Credit",
                                            value: accountService.totalCreditCardDebt.asCurrency(),
                                            iconColor: .warning,
                                            valueColor: .warning
                                        )
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .staggeredFadeIn(index: 0, isVisible: hasAppeared)
                        }
                    }

                    // AI Insights (shown when user has accounts for the AI to analyze)
                    if !accountService.accounts.isEmpty {
                        Section("AI Insights") {
                            AiAdviceCardView()
                                .staggeredFadeIn(index: 1, isVisible: hasAppeared)
                        }
                    }

                    // Error banners
                    if let error = accountService.errorMessage {
                        Section {
                            ErrorBannerView(message: error) {
                                await dataRefreshService.refreshAll()
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
                                        .font(.appHeadline)
                                        .foregroundStyle(Color.textPrimary)
                                    Text(accountService.accounts.isEmpty
                                         ? "Add your first account"
                                         : "\(accountService.accounts.count) account\(accountService.accounts.count == 1 ? "" : "s")")
                                        .font(.appCaption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            } icon: {
                                Image(systemName: "building.columns.fill")
                                    .foregroundStyle(Color.accentCyan)
                            }
                        }
                        .staggeredFadeIn(index: 2, isVisible: hasAppeared)

                        Button {
                            selectedTab = .envelopes
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Envelopes")
                                        .font(.appHeadline)
                                        .foregroundStyle(Color.textPrimary)
                                    Text(envelopeService.envelopes.isEmpty
                                         ? "Create your first envelope"
                                         : "\(envelopeService.envelopeCount) envelope\(envelopeService.envelopeCount == 1 ? "" : "s")")
                                        .font(.appCaption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            } icon: {
                                Image(systemName: "envelope.open.fill")
                                    .foregroundStyle(Color.accentViolet)
                            }
                        }
                        .staggeredFadeIn(index: 3, isVisible: hasAppeared)

                        Button {
                            selectedTab = .transactions
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Transactions")
                                        .font(.appHeadline)
                                        .foregroundStyle(Color.textPrimary)
                                    Text(transactionService.transactions.isEmpty
                                         ? "Add your first transaction"
                                         : "\(transactionService.transactionCount) transaction\(transactionService.transactionCount == 1 ? "" : "s")")
                                        .font(.appCaption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            } icon: {
                                Image(systemName: "arrow.left.arrow.right")
                                    .foregroundStyle(Color.success)
                            }
                        }
                        .staggeredFadeIn(index: 4, isVisible: hasAppeared)
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
                .brandListStyle()
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
            withAnimation(.springSmooth) {
                hasAppeared = true
            }
        }
    }

    private func loadAllData() async {
        await dataRefreshService.refreshAll()
    }
}

#Preview {
    NavigationStack {
        DashboardView(selectedTab: .constant(.dashboard))
            .environment(AuthService())
            .environment(AccountService())
            .environment(EnvelopeService())
            .environment(TransactionService())
            .environment(AiAdviceService())
            .environment(DataRefreshService(accountService: AccountService(), envelopeService: EnvelopeService(), transactionService: TransactionService()))
    }
}
