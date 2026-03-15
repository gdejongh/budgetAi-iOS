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
                        .font(.appHeadline)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    if accountType == .savings {
                        BadgeView(text: "Savings", color: .accentViolet)
                    }
                }

                HStack(spacing: 6) {
                    if let masked = account.maskedNumber {
                        Text(masked)
                            .font(.appCaption)
                            .foregroundStyle(Color.textMuted)
                    }

                    if account.maskedNumber != nil && account.institutionName != nil {
                        Text("·")
                            .font(.appCaption)
                            .foregroundStyle(Color.textMuted)
                    }

                    if let institution = account.institutionName {
                        Text(institution)
                            .font(.appCaption)
                            .foregroundStyle(Color.textMuted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 2) {
                Text(account.currentBalance.asCurrency())
                    .font(.appNumber())
                    .foregroundStyle(balanceColor)

                Text(balanceLabel)
                    .font(.appLabel)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Subviews

    private var iconView: some View {
        Image(systemName: accountType.icon)
            .font(.title3)
            .foregroundStyle(accountType.isCreditCard ? Color.accentOrange : Color.accentCyan)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                    .fill((accountType.isCreditCard ? Color.accentOrange : Color.accentCyan).opacity(0.12))
            )
    }
}
