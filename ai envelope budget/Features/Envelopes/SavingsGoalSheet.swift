//
//  SavingsGoalSheet.swift
//  ai envelope budget
//
//  Created on 3/4/26.
//

import SwiftUI

struct SavingsGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EnvelopeService.self) private var envelopeService

    let envelope: EnvelopeResponse

    @State private var selectedGoalType: GoalType
    @State private var monthlyTarget = ""
    @State private var weeklyTarget = ""
    @State private var goalAmount = ""
    @State private var targetDate: Date
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showRemoveConfirmation = false
    @FocusState private var isAmountFocused: Bool

    private var isEditing: Bool {
        envelope.hasGoal
    }

    init(envelope: EnvelopeResponse) {
        self.envelope = envelope
        _selectedGoalType = State(initialValue: envelope.goalType ?? .monthly)

        // Pre-fill from existing goal
        if let monthly = envelope.monthlyGoalTarget {
            _monthlyTarget = State(initialValue: "\(monthly)")
            _weeklyTarget = State(initialValue: "\(monthly)")
        }
        if let amount = envelope.goalAmount {
            _goalAmount = State(initialValue: "\(amount)")
        }
        if let dateStr = envelope.goalTargetDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            _targetDate = State(initialValue: formatter.date(from: dateStr) ?? Calendar.current.date(byAdding: .month, value: 6, to: Date())!)
        } else {
            _targetDate = State(initialValue: Calendar.current.date(byAdding: .month, value: 6, to: Date())!)
        }
    }

    private var isValid: Bool {
        switch selectedGoalType {
        case .monthly:
            return !monthlyTarget.isEmpty && (Decimal(string: monthlyTarget) ?? 0) > 0
        case .weekly:
            return !weeklyTarget.isEmpty && (Decimal(string: weeklyTarget) ?? 0) > 0
        case .target:
            return !goalAmount.isEmpty && (Decimal(string: goalAmount) ?? 0) > 0
        }
    }

    /// Computed monthly contribution for TARGET type
    private var computedMonthly: Decimal? {
        guard selectedGoalType == .target,
              let total = Decimal(string: goalAmount), total > 0 else { return nil }
        let now = Date()
        let months = Calendar.current.dateComponents([.month], from: now, to: targetDate).month ?? 0
        guard months > 0 else { return nil }
        return total / Decimal(months)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                    VStack(spacing: AppDesign.paddingLg) {
                        // Header
                        headerSection

                        // Goal Type Picker
                        goalTypePicker

                        // Dynamic form based on type
                        switch selectedGoalType {
                        case .monthly:
                            monthlyForm
                        case .weekly:
                            weeklyForm
                        case .target:
                            targetForm
                        }

                        // Error
                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundStyle(Color.danger)
                        }

                        // Save button
                        saveButton

                        // Remove goal (only if editing)
                        if isEditing {
                            removeGoalButton
                        }
                    }
                    .padding(AppDesign.paddingLg)
            }
            .navigationTitle(isEditing ? "Edit Goal" : "Set Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                KeyboardDoneToolbar {
                    isAmountFocused = false
                }
            }
            .confirmationDialog(
                "Remove Goal",
                isPresented: $showRemoveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove Goal", role: .destructive) {
                    Task { await removeGoal() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will clear the savings goal from this envelope.")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "target")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentCyan)

            Text(envelope.name)
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimary)

            Text(isEditing ? "Update your savings goal" : "Set a savings goal to stay on track")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.vertical, AppDesign.paddingSm)
    }

    // MARK: - Goal Type Picker

    private var goalTypePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Goal Type")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: 0) {
                ForEach(GoalType.allCases) { type in
                    goalTypeButton(type)
                }
            }
        }
    }

    private func goalTypeButton(_ type: GoalType) -> some View {
        let isSelected = selectedGoalType == type
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedGoalType = type
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.appCaption)
                Text(type.displayName)
                    .font(.appCaption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? Color.textPrimary : Color.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                    .fill(isSelected ? Color(.systemFill) : Color.clear)
            )
        }
        .padding(4)
    }

    // MARK: - Monthly Form

    private var monthlyForm: some View {
        VStack(spacing: AppDesign.paddingMd) {
            formSection("Monthly Target") {
                HStack {
                    Text("$")
                        .foregroundStyle(Color.textSecondary)
                    TextField("0.00", text: $monthlyTarget)
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.textPrimary)
                }
            }

            infoCard(
                icon: "info.circle.fill",
                text: "You'll aim to allocate this amount to the envelope each month."
            )
        }
    }

    // MARK: - Weekly Form

    private var weeklyForm: some View {
        VStack(spacing: AppDesign.paddingMd) {
            formSection("Weekly Target") {
                HStack {
                    Text("$")
                        .foregroundStyle(Color.textSecondary)
                    TextField("0.00", text: $weeklyTarget)
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.textPrimary)
                }
            }

            if let amount = Decimal(string: weeklyTarget), amount > 0 {
                let approxMonthly = amount * 4
                computedRow("≈ \(approxMonthly.asCurrency())/month", icon: "calendar")
            }

            infoCard(
                icon: "info.circle.fill",
                text: "Track your progress against a weekly spending target."
            )
        }
    }

    // MARK: - Target Form

    private var targetForm: some View {
        VStack(spacing: AppDesign.paddingMd) {
            formSection("Target Amount") {
                HStack {
                    Text("$")
                        .foregroundStyle(Color.textSecondary)
                    TextField("0.00", text: $goalAmount)
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.textPrimary)
                }
            }

            formSection("Target Date") {
                DatePicker(
                    "Date",
                    selection: $targetDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(.accentCyan)
            }

            if let monthly = computedMonthly {
                computedRow("Save \(monthly.asCurrency())/month to reach your goal", icon: "chart.line.uptrend.xyaxis")
            }

            infoCard(
                icon: "info.circle.fill",
                text: "Save toward a specific amount by a target date."
            )
        }
    }

    // MARK: - Computed Row

    private func computedRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.appCaption)
                .foregroundStyle(Color.accentCyan)
            Text(text)
                .font(.appCaption)
                .foregroundStyle(Color.accentCyan)
        }
        .padding(AppDesign.paddingSm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                .fill(Color.accentCyan.opacity(0.08))
        )
    }

    // MARK: - Info Card

    private func infoCard(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.appCaption)
                .foregroundStyle(Color.textMuted)
            Text(text)
                .font(.appCaption)
                .foregroundStyle(Color.textMuted)
        }
        .padding(AppDesign.paddingSm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                .fill(Color(.tertiarySystemFill))
        )
    }

    // MARK: - Buttons

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            Group {
                if isSaving {
                    ProgressView()
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "target")
                        Text(isEditing ? "Update Goal" : "Set Goal")
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .controlSize(.large)
        .disabled(!isValid || isSaving)
    }

    private var removeGoalButton: some View {
        Button {
            showRemoveConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                Text("Remove Goal")
            }
            .font(.body)
            .fontWeight(.medium)
            .foregroundStyle(Color.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.danger.opacity(0.1))
            )
        }
    }

    // MARK: - Form Section

    private func formSection<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)

            content()
                .formFieldBackground()
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        errorMessage = nil

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var goalAmountDecimal: Decimal? = nil
        var monthlyGoalDecimal: Decimal? = nil
        var targetDateStr: String? = nil

        switch selectedGoalType {
        case .monthly:
            monthlyGoalDecimal = Decimal(string: monthlyTarget)
        case .weekly:
            monthlyGoalDecimal = Decimal(string: weeklyTarget)
        case .target:
            goalAmountDecimal = Decimal(string: goalAmount)
            targetDateStr = dateFormatter.string(from: targetDate)
            monthlyGoalDecimal = computedMonthly
        }

        let success = await envelopeService.updateEnvelope(
            envelope,
            goalType: selectedGoalType,
            goalAmount: goalAmountDecimal,
            monthlyGoalTarget: monthlyGoalDecimal,
            goalTargetDate: targetDateStr
        )

        if success {
            dismiss()
        } else {
            errorMessage = envelopeService.errorMessage ?? "Failed to save goal."
        }
        isSaving = false
    }

    // MARK: - Remove Goal

    private func removeGoal() async {
        isSaving = true
        errorMessage = nil

        let success = await envelopeService.updateEnvelope(
            envelope,
            clearGoal: true
        )

        if success {
            dismiss()
        } else {
            errorMessage = envelopeService.errorMessage ?? "Failed to remove goal."
        }
        isSaving = false
    }

}

#Preview {
    SavingsGoalSheet(
        envelope: EnvelopeResponse(
            id: "1", appUserId: "u1", envelopeCategoryId: "c1",
            name: "Groceries", allocatedBalance: 500,
            envelopeType: .standard, linkedAccountId: nil,
            goalAmount: nil, monthlyGoalTarget: nil,
            goalTargetDate: nil, goalType: nil, createdAt: nil
        )
    )
    .environment(EnvelopeService())
}
