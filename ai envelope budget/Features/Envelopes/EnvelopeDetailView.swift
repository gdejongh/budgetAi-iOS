//
//  EnvelopeDetailView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct EnvelopeDetailView: View {
    @Environment(EnvelopeService.self) private var envelopeService
    @Environment(AccountService.self) private var accountService
    @Environment(TransactionService.self) private var transactionService
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
        return envelopeService.remaining(for: env, accounts: accountService.accounts, transactions: transactionService.transactions)
    }

    // CC Payment specific
    private var ccCardBalance: Decimal {
        guard let env = envelope else { return Decimal.zero }
        return envelopeService.cardBalance(for: env, accounts: accountService.accounts)
    }

    private var ccIsUnderfunded: Bool {
        guard let env = envelope else { return false }
        return envelopeService.isUnderfunded(env, accounts: accountService.accounts, transactions: transactionService.transactions)
    }

    private var ccCoverage: Double {
        guard let env = envelope else { return 1.0 }
        return envelopeService.ccCoveragePercent(for: env, accounts: accountService.accounts, transactions: transactionService.transactions)
    }

    private var ccEffectiveFunding: Decimal {
        guard let env = envelope else { return .zero }
        return envelopeService.ccEffectiveFunding(for: env, accounts: accountService.accounts, transactions: transactionService.transactions)
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

    /// Progress toward the goal (0→1), or spending/coverage progress.
    private var progress: Double {
        // CC Payment envelopes use coverage percent
        if let env = envelope, env.isCCPayment {
            return ccCoverage
        }
        if let goalAmount = effectiveGoalAmount, goalAmount > 0, let env = envelope {
            let value: Double
            switch env.goalType {
            case .target:
                value = NSDecimalNumber(decimal: env.allocatedBalance / goalAmount).doubleValue
            case .monthly, .weekly:
                value = NSDecimalNumber(decimal: monthlyAllocation / goalAmount).doubleValue
            case .none:
                value = 0
            }
            return min(value, 1.0)
        }
        guard monthlyAllocation > 0 else { return 0 }
        let spentRatio = NSDecimalNumber(decimal: monthlySpent / monthlyAllocation).doubleValue
        return min(spentRatio, 1.0)
    }

    private var progressTint: Color {
        if let env = envelope, env.isCCPayment {
            return ccIsUnderfunded ? .danger : .success
        }
        if effectiveGoalAmount != nil {
            return progress >= 1.0 ? .success : .accentCyan
        }
        let ratio: Double
        if monthlyAllocation > 0 {
            ratio = NSDecimalNumber(decimal: monthlySpent / monthlyAllocation).doubleValue
        } else {
            ratio = 0
        }
        if ratio > 1 { return .danger }
        if ratio > 0.85 { return .warning }
        return .success
    }

    private var remainingColor: Color {
        if let env = envelope, env.isCCPayment {
            return ccIsUnderfunded ? .danger : .success
        }
        if remaining < 0 { return .danger }
        let threshold = monthlyAllocation * Decimal(0.1)
        if monthlyAllocation > 0, remaining < threshold { return .warning }
        return .success
    }

    var body: some View {
        Group {
            if let envelope {
                detailContent(envelope)
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
                    envelopeMenu(envelope)
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
                .keyboardType(.numbersAndPunctuation)
            Button("Save") {
                Task { await saveAllocation() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Set the budget for \(envelopeService.viewedMonthString). Tip: use +, \u{2212}, \u{00d7}, \u{00f7} for quick math.")
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

    // MARK: - Detail Content

    private func detailContent(_ envelope: EnvelopeResponse) -> some View {
        List {
            // Hero
            Section {
                heroCard(envelope)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // This Month
            thisMonthSection(envelope)

            // Budget
            budgetSection(envelope)

            // Danger Zone
            if !envelope.isCCPayment {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Label("Delete Envelope", systemImage: "trash")
                                .font(.appBody)
                            Spacer()
                            if isDeleting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(isDeleting)
                } header: {
                    Text("Danger Zone")
                        .font(.appCaption)
                        .foregroundStyle(Color.danger)
                }
            }
        }
        .brandListStyle()
    }

    // MARK: - This Month Section

    private func thisMonthSection(_ envelope: EnvelopeResponse) -> some View {
        Section {
            if envelope.isCCPayment {
                LabeledContent {
                    Text(ccCardBalance.asCurrency())
                        .font(.appBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(ccCardBalance > 0 ? Color.warning : Color.success)
                } label: {
                    Text("Card Balance Owed")
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            LabeledContent {
                Text(monthlyAllocation.asCurrency())
                    .font(.appBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
            } label: {
                Text("Allocated")
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
            }
            LabeledContent {
                Text(monthlySpent.asCurrency())
                    .font(.appBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(monthlySpent > 0 ? Color.warning : .textSecondary)
            } label: {
                Text("Spent")
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
            }
            LabeledContent {
                let net = monthlyAllocation - monthlySpent
                Text(net.asCurrency())
                    .font(.appBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(net >= 0 ? Color.success : Color.danger)
            } label: {
                Text("Net")
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
            }
        } header: {
            Text("This Month")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Budget Section

    private func budgetSection(_ envelope: EnvelopeResponse) -> some View {
        Section {
            LabeledContent {
                Text(envelope.allocatedBalance.asCurrency())
                    .font(.appBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
            } label: {
                Text("All-Time Allocated")
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
            }

            Button {
                editedAllocation = "\(monthlyAllocation)"
                showEditAllocation = true
            } label: {
                LabeledContent {
                    HStack(spacing: 4) {
                        Text(monthlyAllocation.asCurrency())
                            .font(.appBody)
                            .fontWeight(.semibold)
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(Color.accentCyan.opacity(0.6))
                    }
                    .foregroundStyle(Color.accentCyan)
                } label: {
                    Text("\(envelopeService.viewedMonthString) Budget")
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            if let goalType = envelope.goalType {
                goalRow(envelope, goalType: goalType)
            } else if !envelope.isCCPayment {
                setGoalButton
            }
        } header: {
            Text("Budget")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Envelope Menu

    private func envelopeMenu(_ envelope: EnvelopeResponse) -> some View {
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
                .foregroundStyle(Color.accentCyan)
                .font(.title3)
        }
    }

    // MARK: - Hero Card

    private func heroCard(_ envelope: EnvelopeResponse) -> some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                    .fill(
                        LinearGradient(
                            colors: envelope.isCCPayment
                                ? [Color.warning.opacity(0.25), Color.warning.opacity(0.05)]
                                : [Color.accentCyan.opacity(0.25), Color.accentViolet.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: envelope.isCCPayment ? "creditcard.fill" : "envelope.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(envelope.isCCPayment ? Color.warning : .accentCyan)
            }
            .shadowGlow(color: envelope.isCCPayment ? .warning : .accentCyan)

            if envelope.isCCPayment {
                ccHeroContent(envelope)
            } else {
                standardHeroContent(envelope)
            }

            // Type + Goal badges
            heroBadges(envelope)
        }
        .frame(maxWidth: .infinity)
        .padding(AppDesign.paddingLg)
    }

    @ViewBuilder
    private func ccHeroContent(_ envelope: EnvelopeResponse) -> some View {
        VStack(spacing: 4) {
            Text("Card Balance")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)

            Text(ccCardBalance.asCurrency())
                .font(.appStatLarge)
                .foregroundStyle(ccCardBalance > 0 ? Color.warning : Color.success)
        }

        BrandProgressBar(value: progress, tint: progressTint)
            .padding(.horizontal, AppDesign.paddingMd)

        Text("\(ccEffectiveFunding.asCurrency()) of \(ccCardBalance.asCurrency()) funded")
            .font(.appCaption)
            .foregroundStyle(Color.textSecondary)

        VStack(spacing: 4) {
            Text("Available for Payment")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
            Text(remaining.asCurrency())
                .font(.appTitle)
                .foregroundStyle(remainingColor)
        }
    }

    @ViewBuilder
    private func standardHeroContent(_ envelope: EnvelopeResponse) -> some View {
        VStack(spacing: 4) {
            Text("Remaining")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)

            Text(remaining.asCurrency())
                .font(.appStatLarge)
                .foregroundStyle(remainingColor)
        }

        BrandProgressBar(value: progress, tint: progressTint)
            .padding(.horizontal, AppDesign.paddingMd)

        if let goalAmount = effectiveGoalAmount {
            goalContextText(envelope, goalAmount: goalAmount)
        }
    }

    @ViewBuilder
    private func goalContextText(_ envelope: EnvelopeResponse, goalAmount: Decimal) -> some View {
        switch envelope.goalType {
        case .target:
            Text("\(envelope.allocatedBalance.asCurrency()) of \(goalAmount.asCurrency()) saved")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
        case .monthly, .weekly:
            Text("\(monthlyAllocation.asCurrency()) of \(goalAmount.asCurrency()) funded")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func heroBadges(_ envelope: EnvelopeResponse) -> some View {
        HStack(spacing: 8) {
            if envelope.isCCPayment {
                BadgeView(text: "CC Payment", color: .warning)
                if ccIsUnderfunded {
                    BadgeView(text: "Underfunded", color: .danger)
                } else {
                    BadgeView(text: "Fully Funded", color: .success)
                }
            }
            if let goalType = envelope.goalType {
                BadgeView(text: goalType.displayName + " Goal", color: .accentCyan)
            }
        }
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
                .font(.appCaption)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: goalType.icon)
                            .font(.appCaption)
                            .foregroundStyle(Color.accentCyan)
                        Text("\(goalType.displayName) Goal")
                            .font(.appBody)
                            .foregroundStyle(Color.textPrimary)
                    }

                    if let target = envelope.goalAmount, goalType == .target {
                        Text("Target: \(target.asCurrency())")
                            .font(.appCaption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    if let monthly = envelope.monthlyGoalTarget {
                        Text("Goal: \(monthly.asCurrency())/\(goalType == .weekly ? "wk" : "mo")")
                            .font(.appCaption)
                            .foregroundStyle(Color.textSecondary)
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
                        .foregroundStyle(Color.accentCyan.opacity(0.6))
                }
                .font(.appCaption)
                .foregroundStyle(Color.accentCyan)
            } label: {
                Label("Savings Goal", systemImage: "target")
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
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
        guard let amount = evaluateMathExpression(editedAllocation), amount >= 0 else { return }
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
