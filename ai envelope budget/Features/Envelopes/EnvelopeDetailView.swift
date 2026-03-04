//
//  EnvelopeDetailView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct EnvelopeDetailView: View {
    @Environment(EnvelopeService.self) private var envelopeService
    @Environment(\.dismiss) private var dismiss

    let envelopeId: String

    @State private var showEditName = false
    @State private var showEditAllocation = false
    @State private var showDeleteConfirmation = false
    @State private var showGoalSheet = false
    @State private var editedName = ""
    @State private var editedAllocation = ""
    @State private var isDeleting = false
    @State private var isSaving = false

    private var envelope: EnvelopeResponse? {
        envelopeService.envelopes.first { $0.id == envelopeId }
    }

    private var monthlyAllocation: Decimal {
        guard let env = envelope else { return Decimal.zero }
        return envelopeService.monthlyAllocation(for: env)
    }

    private var monthlySpent: Decimal {
        guard let env = envelope else { return Decimal.zero }
        return envelopeService.monthlySpent(for: env)
    }

    private var remaining: Decimal {
        guard let env = envelope else { return Decimal.zero }
        return envelopeService.remaining(for: env)
    }

    /// The goal target amount, resolved from the right field per goal type.
    private var effectiveGoalAmount: Decimal? {
        guard let env = envelope, env.hasGoal else { return nil }
        switch env.goalType {
        case .target:
            return env.goalAmount
        case .monthly, .weekly:
            if let target = env.monthlyGoalTarget, target > 0 { return target }
            if let goal = env.goalAmount, goal > 0 { return goal }
            return nil
        case .none:
            return nil
        }
    }

    private var progress: Double {
        if let goalAmount = effectiveGoalAmount, goalAmount > 0, let env = envelope {
            switch env.goalType {
            case .target:
                return min(
                    NSDecimalNumber(decimal: env.allocatedBalance / goalAmount).doubleValue,
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
        guard monthlyAllocation > 0 else { return 0 }
        return min(
            NSDecimalNumber(decimal: monthlySpent / monthlyAllocation).doubleValue,
            1.0
        )
    }

    private var progressTint: Color {
        if effectiveGoalAmount != nil {
            return progress >= 1.0 ? .green : .accentColor
        }
        let ratio = monthlyAllocation > 0
            ? NSDecimalNumber(decimal: monthlySpent / monthlyAllocation).doubleValue
            : 0
        if ratio > 1    { return .red }
        if ratio > 0.85 { return .orange }
        return .green
    }

    private var remainingColor: Color {
        if remaining < 0 { return .red }
        if monthlyAllocation > 0, remaining < monthlyAllocation * Decimal(0.1) { return .orange }
        return .green
    }

    var body: some View {
        Group {
            if let envelope {
                List {
                    // Hero
                    Section {
                        heroCard(envelope)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    // This Month
                    Section("This Month") {
                        LabeledContent("Allocated", value: monthlyAllocation.asCurrency())
                        LabeledContent("Spent") {
                            Text(monthlySpent.asCurrency())
                                .foregroundStyle(monthlySpent > 0 ? Color.warning : .secondary)
                        }
                        LabeledContent("Net") {
                            Text((monthlyAllocation - monthlySpent).asCurrency())
                                .foregroundStyle(monthlyAllocation - monthlySpent >= 0 ? Color.success : Color.danger)
                        }
                    }

                    // Budget
                    Section("Budget") {
                        LabeledContent("All-Time Allocated", value: envelope.allocatedBalance.asCurrency())

                        Button {
                            editedAllocation = "\(monthlyAllocation)"
                            showEditAllocation = true
                        } label: {
                            LabeledContent {
                                HStack(spacing: 4) {
                                    Text(monthlyAllocation.asCurrency())
                                        .fontWeight(.medium)
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundStyle(.tertiary)
                                }
                                .foregroundStyle(Color.accentColor)
                            } label: {
                                Text("\(envelopeService.viewedMonthString) Budget")
                            }
                        }

                        if let goalType = envelope.goalType {
                            goalRow(envelope, goalType: goalType)
                        } else if !envelope.isCCPayment {
                            setGoalButton
                        }
                    }

                    // Danger Zone
                    if !envelope.isCCPayment {
                        Section {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Label("Delete Envelope", systemImage: "trash")
                                    Spacer()
                                    if isDeleting {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                }
                            }
                            .disabled(isDeleting)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Envelope Not Found",
                    systemImage: "envelope.open",
                    description: Text("This envelope may have been deleted.")
                )
            }
        }
        .navigationTitle(envelope?.name ?? "Envelope")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let envelope, !envelope.isCCPayment {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            editedName = envelope.name
                            showEditName = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button {
                            showGoalSheet = true
                        } label: {
                            Label(envelope.hasGoal ? "Edit Goal" : "Set Goal", systemImage: "target")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Envelope", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.title3)
                    }
                }
            }
        }
        .alert("Rename Envelope", isPresented: $showEditName) {
            TextField("Name", text: $editedName)
            Button("Save") {
                Task { await saveName() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a new name for this envelope.")
        }
        .alert("Edit Allocation", isPresented: $showEditAllocation) {
            TextField("Amount", text: $editedAllocation)
                .keyboardType(.decimalPad)
            Button("Save") {
                Task { await saveAllocation() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Set the budget for \(envelopeService.viewedMonthString).")
        }
        .confirmationDialog(
            "Delete Envelope",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteEnvelope() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure? This will remove the envelope and all its allocations.")
        }
        .sheet(isPresented: $showGoalSheet) {
            if let envelope {
                SavingsGoalSheet(envelope: envelope)
            }
        }
    }

    // MARK: - Hero Card

    private func heroCard(_ envelope: EnvelopeResponse) -> some View {
        VStack(spacing: 16) {
            Image(systemName: envelope.isCCPayment ? "creditcard.fill" : "envelope.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 4) {
                Text(envelope.isCCPayment ? "Available for Payment" : "Remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(remaining.asCurrency())
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(remainingColor)
            }

            // Progress bar
            ProgressView(value: progress)
                .tint(progressTint)
                .scaleEffect(y: 1.5)
                .padding(.horizontal, AppDesign.paddingMd)

            // Goal context
            if let goalAmount = effectiveGoalAmount {
                switch envelope.goalType {
                case .target:
                    Text("\(envelope.allocatedBalance.asCurrency()) of \(goalAmount.asCurrency()) saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .monthly, .weekly:
                    Text("\(monthlyAllocation.asCurrency()) of \(goalAmount.asCurrency()) funded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .none:
                    EmptyView()
                }
            }

            // Type + Goal badges
            HStack(spacing: 8) {
                if envelope.isCCPayment {
                    badge("CC Payment", color: .accentViolet)
                }
                if let goalType = envelope.goalType {
                    badge(goalType.displayName + " Goal", color: .accentCyan)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppDesign.paddingLg)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    // MARK: - Goal Row

    private func goalRow(_ envelope: EnvelopeResponse, goalType: GoalType) -> some View {
        Button {
            showGoalSheet = true
        } label: {
            LabeledContent {
                HStack(spacing: 4) {
                    Text("Edit")
                        .foregroundStyle(Color.accentCyan.opacity(0.7))
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(Color.accentCyan.opacity(0.6))
                }
                .font(.caption)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: goalType.icon)
                            .font(.caption)
                            .foregroundStyle(Color.accentCyan)
                        Text("\(goalType.displayName) Goal")
                            .font(.subheadline)
                    }

                    if let target = envelope.goalAmount, goalType == .target {
                        Text("Target: \(target.asCurrency())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let monthly = envelope.monthlyGoalTarget {
                        Text("Goal: \(monthly.asCurrency())/\(goalType == .weekly ? "wk" : "mo")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Set Goal Button

    private var setGoalButton: some View {
        Button {
            showGoalSheet = true
        } label: {
            LabeledContent {
                HStack(spacing: 4) {
                    Text("Set Goal")
                        .fontWeight(.semibold)
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
                .foregroundStyle(Color.accentCyan)
            } label: {
                Label("Savings Goal", systemImage: "target")
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Actions

    private func saveName() async {
        guard let envelope else { return }
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        _ = await envelopeService.updateEnvelope(envelope, name: trimmed)
        isSaving = false
    }

    private func saveAllocation() async {
        guard let envelope else { return }
        let cleaned = editedAllocation
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let amount = Decimal(string: cleaned), amount >= 0 else { return }
        isSaving = true
        _ = await envelopeService.setAllocation(for: envelope, amount: amount)
        isSaving = false
    }

    private func deleteEnvelope() async {
        guard let envelope else { return }
        isDeleting = true
        let success = await envelopeService.deleteEnvelope(envelope)
        if success { dismiss() }
        isDeleting = false
    }
}
