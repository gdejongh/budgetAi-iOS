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
    var isEditing: Bool = false
    @Binding var editedAllocation: String

    // CC Payment specific
    var cardBalance: Decimal? = nil
    var isUnderfunded: Bool = false
    var ccCoveragePercent: Double? = nil

    // MARK: - Computed

    /// The goal target amount, resolved from the right field per goal type.
    private var effectiveGoalAmount: Decimal? {
        guard envelope.hasGoal else { return nil }
        switch envelope.goalType {
        case .target:
            return envelope.goalAmount
        case .monthly, .weekly:
            // Prefer monthlyGoalTarget; fall back to goalAmount
            if let target = envelope.monthlyGoalTarget, target > 0 { return target }
            if let goal = envelope.goalAmount, goal > 0 { return goal }
            return nil
        case .none:
            return nil
        }
    }

    /// Progress toward the goal (0→1), or spending progress if no goal.
    private var progress: Double {
        // CC Payment envelopes use coverage percent
        if envelope.isCCPayment, let coverage = ccCoveragePercent {
            return coverage
        }
        if let goalAmount = effectiveGoalAmount, goalAmount > 0 {
            switch envelope.goalType {
            case .target:
                return min(
                    NSDecimalNumber(decimal: envelope.allocatedBalance / goalAmount).doubleValue,
                    1.0
                )
            case .monthly, .weekly:
                return min(
                    NSDecimalNumber(decimal: monthlyAllocation / goalAmount).doubleValue,
                    1.0
                )
            case .none:
                break
            }
        }
        // No goal — show spending usage
        guard monthlyAllocation > 0 else { return 0 }
        return min(
            NSDecimalNumber(decimal: monthlySpent / monthlyAllocation).doubleValue,
            1.0
        )
    }

    private var progressTint: Color {
        // CC Payment: red when underfunded, green when fully funded
        if envelope.isCCPayment {
            return isUnderfunded ? .danger : .success
        }
        if effectiveGoalAmount != nil {
            return progress >= 1.0 ? .success : .accentCyan
        }
        // Spending: green → orange → red as budget is consumed
        let ratio = monthlyAllocation > 0
            ? NSDecimalNumber(decimal: monthlySpent / monthlyAllocation).doubleValue
            : 0
        if ratio > 1    { return .danger }
        if ratio > 0.85 { return .warning }
        return .success
    }

    private var remainingColor: Color {
        if envelope.isCCPayment { return isUnderfunded ? .danger : .success }
        if remaining < 0 { return .danger }
        if monthlyAllocation > 0, remaining < monthlyAllocation * Decimal(0.1) {
            return .warning
        }
        return .textPrimary
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1 — Name + remaining/owed
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: envelope.isCCPayment ? "creditcard.fill" : "envelope.fill")
                    .foregroundStyle(envelope.isCCPayment ? Color.accentOrange : Color.accentViolet)
                    .font(.subheadline)

                Text(envelope.name)
                    .font(.appBody)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                if envelope.isCCPayment {
                    BadgeView(text: "CC", color: .accentOrange)
                    if isUnderfunded {
                        BadgeView(text: "Underfunded", color: .danger)
                    }
                }

                Spacer()

                // Remaining / inline edit
                if isEditing {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(spacing: 2) {
                            Text("$")
                                .font(.appNumber())
                                .foregroundStyle(Color.textSecondary)
                            Text(editedAllocation.isEmpty ? "0" : editedAllocation)
                                .font(.appNumber())
                                .foregroundStyle(Color.textPrimary)
                                .frame(minWidth: 40, alignment: .trailing)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentCyan.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.accentCyan.opacity(0.4), lineWidth: 1)
                                )
                        )
                        Text("budget")
                            .font(.appLabel)
                            .foregroundStyle(Color.accentCyan)
                    }
                } else if envelope.isCCPayment, let debt = cardBalance {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(debt.asCurrency())
                            .font(.appNumber())
                            .foregroundStyle(debt > 0 ? Color.warning : Color.success)

                        Text("owed")
                            .font(.appLabel)
                            .foregroundStyle(Color.textSecondary)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(remaining.asCurrency())
                            .font(.appNumber())
                            .foregroundStyle(remainingColor)

                        Text("remaining")
                            .font(.appLabel)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }

            // Row 2 — Progress bar
            BrandProgressBar(value: progress, tint: progressTint)

            // Row 2.5 — Math operator buttons (visible when editing)
            if isEditing {
                HStack(spacing: 8) {
                    Spacer()
                    ForEach(
                        [("+", "+"), ("−", "-"), ("×", "*"), ("÷", "/")],
                        id: \.0
                    ) { label, op in
                        Button {
                            editedAllocation.append(op)
                        } label: {
                            Text(label)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .frame(width: 38, height: 34)
                                .background(Color.accentCyan.opacity(0.15))
                                .foregroundStyle(Color.accentCyan)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.accentCyan.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Row 3 — Context: spent/goal info + goal type badge
            HStack {
                if envelope.isCCPayment, let debt = cardBalance {
                    Text("\(envelope.allocatedBalance.asCurrency()) of \(debt.asCurrency()) funded")
                } else if let goalAmount = effectiveGoalAmount {
                    switch envelope.goalType {
                    case .target:
                        Text("\(envelope.allocatedBalance.asCurrency()) of \(goalAmount.asCurrency()) saved")
                    case .monthly, .weekly:
                        Text("\(monthlyAllocation.asCurrency()) of \(goalAmount.asCurrency()) funded")
                    case .none:
                        Text("\(monthlySpent.asCurrency()) of \(monthlyAllocation.asCurrency()) spent")
                    }
                } else {
                    Text("\(monthlySpent.asCurrency()) of \(monthlyAllocation.asCurrency()) spent")
                }

                Spacer()

                if envelope.isCCPayment {
                    Text("Auto-managed")
                        .font(.appLabel)
                        .foregroundStyle(Color.accentOrange)
                } else if let goalType = envelope.goalType {
                    Label(goalType.displayName, systemImage: goalType.icon)
                }
            }
            .font(.appCaption)
            .foregroundStyle(Color.textSecondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(envelope.name), \(remaining.asCurrencyAccessibilityLabel()) remaining"
        )
    }

    // MARK: - Subviews
}
