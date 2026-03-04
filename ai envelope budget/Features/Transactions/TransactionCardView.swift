//
//  TransactionCardView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct TransactionCardView: View {
    let transaction: TransactionResponse
    let accountName: String?
    let envelopeName: String?

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            iconView

            // Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(transaction.displayTitle)
                        .font(.appSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    if transaction.resolvedType != .standard {
                        BadgeView(text: transaction.resolvedType.displayName, color: badgeColor)
                    }

                    if transaction.pending == true {
                        BadgeView(text: "PENDING", color: .warning)
                    }
                }

                HStack(spacing: 6) {
                    if let acctName = accountName {
                        Text(acctName)
                            .font(.caption2)
                            .foregroundStyle(Color.textMuted)
                    }

                    if accountName != nil && envelopeName != nil {
                        Circle()
                            .fill(Color.textMuted)
                            .frame(width: 3, height: 3)
                    }

                    if let envName = envelopeName {
                        Text(envName)
                            .font(.caption2)
                            .foregroundStyle(Color.accentViolet.opacity(0.8))
                    }
                }

                if let subtitle = transaction.displaySubtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amount + Date
            VStack(alignment: .trailing, spacing: 3) {
                Text(formatAmount(transaction.amount))
                    .font(.appNumber(.subheadline))
                    .foregroundStyle(transaction.isIncome ? Color.success : Color.danger)

                Text(transaction.formattedDate)
                    .font(.appLabel)
                    .foregroundStyle(Color.textMuted)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Icon View

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(iconBackground)
                .frame(width: 36, height: 36)

            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
        }
    }

    private var iconName: String {
        switch transaction.resolvedType {
        case .ccPayment: return "creditcard.fill"
        case .transfer: return "arrow.triangle.swap"
        case .standard:
            return transaction.isIncome ? "arrow.down.left" : "arrow.up.right"
        }
    }

    private var iconColor: Color {
        switch transaction.resolvedType {
        case .ccPayment: return .accentViolet
        case .transfer: return .accentCyan
        case .standard:
            return transaction.isIncome ? .success : .danger
        }
    }

    private var iconBackground: Color {
        iconColor.opacity(0.12)
    }

    private var badgeColor: Color {
        switch transaction.resolvedType {
        case .ccPayment: return .accentViolet
        case .transfer: return .accentCyan
        case .standard: return .textMuted
        }
    }

    // MARK: - Helpers

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+$"
        formatter.negativePrefix = "-$"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

#Preview {
    VStack(spacing: 12) {
        TransactionCardView(
            transaction: TransactionResponse(
                id: "1", appUserId: "u1", bankAccountId: "a1", envelopeId: "e1",
                amount: -42.50, description: "Weekly groceries", transactionDate: "2026-03-01",
                transactionType: "STANDARD", linkedTransactionId: nil, createdAt: nil,
                pending: false, merchantName: "Whole Foods", plaidCategory: nil, plaidTransactionId: nil
            ),
            accountName: "Chase Checking",
            envelopeName: "Groceries"
        )

        TransactionCardView(
            transaction: TransactionResponse(
                id: "2", appUserId: "u1", bankAccountId: "a1", envelopeId: nil,
                amount: 3200.00, description: "Paycheck", transactionDate: "2026-03-01",
                transactionType: "STANDARD", linkedTransactionId: nil, createdAt: nil,
                pending: false, merchantName: "Employer Inc", plaidCategory: nil, plaidTransactionId: nil
            ),
            accountName: "Chase Checking",
            envelopeName: nil
        )
    }
    .padding()
    .background(Color.bgPrimary)
}
