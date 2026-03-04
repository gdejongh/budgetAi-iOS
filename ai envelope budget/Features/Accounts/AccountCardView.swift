//
//  AccountCardView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct AccountCardView: View {
    let account: BankAccountResponse

    private var accountType: AccountType { account.resolvedType }

    private var balanceColor: Color {
        if accountType.isCreditCard {
            return account.currentBalance > 0 ? .warning : .success
        }
        return account.currentBalance >= 0 ? .success : .danger
    }

    private var balanceLabel: String {
        accountType.isCreditCard ? "Balance Owed" : "Available"
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            iconView

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(account.name)
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    if accountType == .savings {
                        typeBadge("Savings", color: .accentViolet)
                    }

                    if account.isPlaidLinked {
                        linkedBadge
                    }
                }

                HStack(spacing: 6) {
                    if let masked = account.maskedNumber {
                        Text(masked)
                            .font(.caption)
                            .foregroundStyle(Color.textMuted)
                    }

                    if account.maskedNumber != nil && account.institutionName != nil {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(Color.textMuted)
                    }

                    if let institution = account.institutionName {
                        Text(institution)
                            .font(.caption)
                            .foregroundStyle(Color.textMuted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(account.currentBalance))
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(balanceColor)

                Text(balanceLabel)
                    .font(.caption2)
                    .foregroundStyle(Color.textMuted)
            }
        }
        .padding(AppDesign.paddingMd)
        .glassCard()
    }

    // MARK: - Subviews

    private var iconView: some View {
        Image(systemName: accountType.icon)
            .font(.title3)
            .foregroundStyle(LinearGradient.brand)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                    .fill(Color.accentCyan.opacity(0.1))
            )
    }

    private func typeBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }

    private var linkedBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "link")
                .font(.system(size: 8, weight: .bold))
            Text("Linked")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Color.accentCyan)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color.accentCyan.opacity(0.15))
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
