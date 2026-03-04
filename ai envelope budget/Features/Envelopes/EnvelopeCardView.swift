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
    var allocationFocused: FocusState<Bool>.Binding

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
            return isUnderfunded ? .red : .green
        }
        if effectiveGoalAmount != nil {
            return progress >= 1.0 ? .green : .accentColor
        }
        // Spending: green → orange → red as budget is consumed
        let ratio = monthlyAllocation > 0
            ? NSDecimalNumber(decimal: monthlySpent / monthlyAllocation).doubleValue
            : 0
        if ratio > 1    { return .red }
        if ratio > 0.85 { return .orange }
        return .green
    }

    private var remainingColor: Color {
        if envelope.isCCPayment { return isUnderfunded ? .red : .green }
        if remaining < 0 { return .red }
        if monthlyAllocation > 0, remaining < monthlyAllocation * Decimal(0.1) {
            return .orange
        }
        return .primary
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1 — Name + remaining/owed
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: envelope.isCCPayment ? "creditcard.fill" : "envelope.fill")
                    .foregroundStyle(envelope.isCCPayment ? Color.orange : Color.accentColor)
                    .font(.subheadline)

                Text(envelope.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                if envelope.isCCPayment {
                    ccBadge
                    if isUnderfunded {
                        underfundedBadge
                    }
                }

                Spacer()

                // Remaining / inline edit
                if isEditing {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(spacing: 2) {
                            Text("$")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TextField("0", text: $editedAllocation)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused(allocationFocused)
                                .frame(width: 80)
                        }
                        Text("budget")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                    }
                } else if envelope.isCCPayment, let debt = cardBalance {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(debt.asCurrency())
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(debt > 0 ? Color.warning : Color.success)

                        Text("owed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(remaining.asCurrency())
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(remainingColor)

                        Text("remaining")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Row 2 — Progress bar
            ProgressView(value: progress)
                .tint(progressTint)

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
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else if let goalType = envelope.goalType {
                    Label(goalType.displayName, systemImage: goalType.icon)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(envelope.name), \(remaining.asCurrencyAccessibilityLabel()) remaining"
        )
    }

    // MARK: - Subviews

    private var ccBadge: some View {
        Text("CC")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.orange.opacity(0.15)))
    }

    private var underfundedBadge: some View {
        Text("Underfunded")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.red)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.red.opacity(0.15)))
    }
}
