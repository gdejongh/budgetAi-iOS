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
        VStack(spacing: 6) {
            // Row 1: Merchant + Amount
            HStack {
                Text(transaction.displayTitle)
                    .font(.appBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                if transaction.pending == true {
                    BadgeView(text: "PENDING", color: .warning)
                }

                Spacer()

                Text(formatAmount(transaction.amount))
                    .font(.appNumber(.subheadline))
                    .fontWeight(.semibold)
                    .foregroundStyle(transaction.isIncome ? Color.success : Color.textPrimary)
            }

            // Row 2: Envelope badge + Account name
            HStack(spacing: 6) {
                if let envName = envelopeName {
                    BadgeView(
                        text: envName,
                        color: .accentViolet,
                        icon: "envelope.fill"
                    )
                } else if transaction.resolvedType != .standard {
                    BadgeView(
                        text: transaction.resolvedType.displayName,
                        color: badgeColor,
                        icon: transaction.resolvedType.icon
                    )
                } else {
                    BadgeView(
                        text: "Uncategorized",
                        color: .textMuted,
                        icon: "questionmark.circle"
                    )
                }

                Spacer()

                if let acctName = accountName {
                    Text(acctName)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            // Row 3: Description / subtitle (if different from merchant)
            if let subtitle = transaction.displaySubtitle {
                HStack {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.textMuted)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private var badgeColor: Color {
        switch transaction.resolvedType {
        case .ccPayment: return .accentViolet
        case .transfer: return .accentCyan
        case .standard: return .textMuted
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+$"
        formatter.negativePrefix = "−$"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

#Preview {
    List {
        Section("March 9, 2026") {
            TransactionCardView(
                transaction: TransactionResponse(
                    id: "1", appUserId: "u1", bankAccountId: "a1", envelopeId: "e1",
                    amount: -42.50, description: "Weekly groceries", transactionDate: "2026-03-09",
                    transactionType: "STANDARD", linkedTransactionId: nil, createdAt: nil,
                    pending: false, merchantName: "Whole Foods", plaidCategory: nil, plaidTransactionId: nil
                ),
                accountName: "Chase Checking",
                envelopeName: "Groceries"
            )

            TransactionCardView(
                transaction: TransactionResponse(
                    id: "2", appUserId: "u1", bankAccountId: "a1", envelopeId: nil,
                    amount: 3200.00, description: "Paycheck", transactionDate: "2026-03-09",
                    transactionType: "STANDARD", linkedTransactionId: nil, createdAt: nil,
                    pending: false, merchantName: "Employer Inc", plaidCategory: nil, plaidTransactionId: nil
                ),
                accountName: "Chase Checking",
                envelopeName: nil
            )

            TransactionCardView(
                transaction: TransactionResponse(
                    id: "3", appUserId: "u1", bankAccountId: "a2", envelopeId: nil,
                    amount: -15000.00, description: nil, transactionDate: "2026-03-09",
                    transactionType: "TRANSFER", linkedTransactionId: "4", createdAt: nil,
                    pending: false, merchantName: "Transfer to Savings", plaidCategory: nil, plaidTransactionId: nil
                ),
                accountName: "Wealthfront",
                envelopeName: nil
            )
        }
    }
    .brandListStyle()
}
