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

    var body: some View {
        ZStack {
            Color.bgPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(LinearGradient.brand)
                            .shadow(color: .accentCyan.opacity(0.3), radius: 16, x: 0, y: 4)

                        GradientText("Dashboard", font: .system(size: 28, weight: .bold))

                        if let email = authService.userEmail {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    .padding(.top, AppDesign.paddingMd)

                    // Account Summary Card
                    if !accountService.accounts.isEmpty {
                        accountSummaryCard
                    }

                    // Feature Cards
                    VStack(spacing: 16) {
                        infoCard(
                            icon: "building.columns.fill",
                            title: "Accounts",
                            subtitle: accountService.accounts.isEmpty
                                ? "Add your first account"
                                : "\(accountService.accounts.count) account\(accountService.accounts.count == 1 ? "" : "s")"
                        )
                        infoCard(
                            icon: "envelope.open.fill",
                            title: "Envelopes",
                            subtitle: envelopeService.envelopes.isEmpty
                                ? "Create your first envelope"
                                : "\(envelopeService.envelopeCount) envelope\(envelopeService.envelopeCount == 1 ? "" : "s")"
                        )
                        infoCard(
                            icon: "arrow.left.arrow.right",
                            title: "Transactions",
                            subtitle: transactionService.transactions.isEmpty
                                ? "Add your first transaction"
                                : "\(transactionService.transactionCount) transaction\(transactionService.transactionCount == 1 ? "" : "s")"
                        )
                    }
                    .padding(.horizontal, AppDesign.paddingLg)

                    Spacer(minLength: 40)

                    // Logout button
                    Button {
                        Task {
                            await authService.logout()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.danger)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                .fill(Color.danger.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                        .stroke(Color.danger.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.bottom, 32)
                }
                .padding(.top, 20)
            }
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if accountService.accounts.isEmpty {
                await accountService.fetchAccounts()
            }
            if envelopeService.envelopes.isEmpty {
                await envelopeService.loadAll()
            }
            if transactionService.transactions.isEmpty {
                await transactionService.fetchTransactions()
            }
        }
    }

    // MARK: - Account Summary

    private var accountSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Net Worth")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
            }

            HStack {
                Text(formatCurrency(accountService.netWorth))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(accountService.netWorth >= 0 ? Color.success : Color.danger)
                Spacer()
            }

            Divider()
                .overlay(Color.borderSubtle)

            HStack(spacing: AppDesign.paddingLg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatCurrency(accountService.totalBankBalance))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.success)
                    Text("\(accountService.bankAccounts.count) Bank")
                        .font(.caption2)
                        .foregroundStyle(Color.textMuted)
                }

                if !accountService.creditCards.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatCurrency(accountService.totalCreditCardDebt))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.warning)
                        Text("\(accountService.creditCards.count) Credit")
                            .font(.caption2)
                            .foregroundStyle(Color.textMuted)
                    }
                }

                Spacer()
            }
        }
        .padding(AppDesign.paddingMd)
        .glassCard()
        .padding(.horizontal, AppDesign.paddingLg)
    }

    private func infoCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(LinearGradient.brand)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.textMuted)
        }
        .padding(AppDesign.paddingMd)
        .glassCard()
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
        DashboardView()
            .environment(AuthService())
            .environment(AccountService())
            .environment(EnvelopeService())
            .environment(TransactionService())
    }
}
