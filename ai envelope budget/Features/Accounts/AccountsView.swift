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
        ZStack {
            Color.bgPrimary
                .ignoresSafeArea()

            if accountService.isLoading && accountService.accounts.isEmpty {
                loadingView
            } else if accountService.accounts.isEmpty {
                emptyStateView
            } else {
                accountsList
            }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(LinearGradient.brand)
                        .font(.title3)
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
        ScrollView {
            VStack(spacing: AppDesign.paddingLg) {
                // Net Worth Summary
                netWorthCard

                // Error banner
                if let error = accountService.errorMessage {
                    errorBanner(error)
                }

                // Bank Accounts Section
                if !accountService.bankAccounts.isEmpty {
                    accountSection(
                        title: "Bank Accounts",
                        icon: "building.columns.fill",
                        accounts: accountService.bankAccounts
                    )
                }

                // Credit Cards Section
                if !accountService.creditCards.isEmpty {
                    accountSection(
                        title: "Credit Cards",
                        icon: "creditcard.fill",
                        accounts: accountService.creditCards
                    )
                }
            }
            .padding(.horizontal, AppDesign.paddingLg)
            .padding(.vertical, AppDesign.paddingMd)
        }
    }

    // MARK: - Net Worth Card

    private var netWorthCard: some View {
        VStack(spacing: 8) {
            Text("Net Worth")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)

            GradientText(
                formatCurrency(accountService.netWorth),
                font: .system(size: 32, weight: .bold, design: .rounded)
            )

            HStack(spacing: AppDesign.paddingLg) {
                summaryItem(
                    label: "Bank Accounts",
                    value: formatCurrency(accountService.totalBankBalance),
                    color: .success
                )

                if !accountService.creditCards.isEmpty {
                    summaryItem(
                        label: "Credit Cards",
                        value: formatCurrency(accountService.totalCreditCardDebt),
                        color: .warning
                    )
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(AppDesign.paddingLg)
        .glassCard()
    }

    private func summaryItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.textMuted)
        }
    }

    // MARK: - Account Section

    private func accountSection(
        title: String,
        icon: String,
        accounts: [BankAccountResponse]
    ) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.paddingSm) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(LinearGradient.brand)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Spacer()

                Text("\(accounts.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.bgCardHover)
                    )
            }
            .padding(.horizontal, 4)

            ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                NavigationLink(value: account.id ?? "") {
                    AccountCardView(account: account)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(
                    .spring(duration: 0.4).delay(Double(index) * 0.05),
                    value: accounts.count
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 56))
                .foregroundStyle(LinearGradient.brand)
                .shadow(color: .accentCyan.opacity(0.3), radius: 16)

            VStack(spacing: 8) {
                Text("No Accounts Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)

                Text("Add a bank account or credit card to start tracking your finances.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                showCreateSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Account")
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

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.accentCyan)

            Text("Loading accounts…")
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
                Task {
                    await accountService.fetchAccounts()
                }
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

#Preview {
    NavigationStack {
        AccountsView()
            .environment(AccountService())
    }
}
