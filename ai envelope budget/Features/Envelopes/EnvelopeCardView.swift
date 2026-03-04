//
//  EnvelopeCardView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct EnvelopeCardView: View {
    let envelope: EnvelopeResponse
    let monthlyAllocation: Decimal
    let monthlySpent: Decimal
    let remaining: Decimal

    private var isOverspent: Bool { remaining < 0 }

    private var progress: Double {
        guard envelope.allocatedBalance > 0 else { return 0 }
        let totalSpent = envelope.allocatedBalance - remaining
        let ratio = NSDecimalNumber(decimal: totalSpent / envelope.allocatedBalance).doubleValue
        return min(max(ratio, 0), 1)
    }

    private var remainingColor: Color {
        if remaining < 0 { return .danger }
        if remaining < monthlyAllocation * Decimal(0.1) { return .warning }
        return .success
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: icon + name + remaining
            HStack(alignment: .top) {
                // Icon
                Image(systemName: envelope.isCCPayment ? "creditcard.fill" : "envelope.fill")
                    .font(.subheadline)
                    .foregroundStyle(LinearGradient.brand)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                            .fill(Color.accentCyan.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(envelope.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)

                        if envelope.isCCPayment {
                            Text("CC")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.accentViolet)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(Color.accentViolet.opacity(0.15))
                                )
                        }

                        if envelope.hasGoal {
                            Image(systemName: envelope.goalType?.icon ?? "flag")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.accentCyan)
                        }
                    }

                    // Subtitle: monthly allocation
                    Text("\(formatCurrency(monthlyAllocation))/mo")
                        .font(.caption2)
                        .foregroundStyle(Color.textMuted)
                }

                Spacer()

                // Remaining amount
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(remaining))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(remainingColor)

                    Text(envelope.isCCPayment ? "Available" : "Remaining")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.bgCardHover)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            isOverspent
                                ? LinearGradient(colors: [.danger, .danger.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient.brand
                        )
                        .frame(width: max(geometry.size.width * progress, 0), height: 6)
                        .animation(.spring(duration: 0.4), value: progress)
                }
            }
            .frame(height: 6)

            // Bottom row: Allocated + Spent
            HStack {
                Label {
                    Text(formatCurrency(monthlyAllocation))
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                } icon: {
                    Text("Allocated")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                }

                Spacer()

                Label {
                    Text(formatCurrency(monthlySpent))
                        .font(.caption2)
                        .foregroundStyle(monthlySpent > 0 ? Color.warning : Color.textSecondary)
                } icon: {
                    Text("Spent")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                }
            }
        }
        .padding(AppDesign.paddingSm + 4)
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
