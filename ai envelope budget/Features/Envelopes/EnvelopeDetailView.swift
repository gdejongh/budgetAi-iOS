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

    private var progress: Double {
        guard let env = envelope, env.allocatedBalance > 0 else { return 0 }
        let totalSpent = env.allocatedBalance - remaining
        let ratio = NSDecimalNumber(decimal: totalSpent / env.allocatedBalance).doubleValue
        return min(max(ratio, 0), 1)
    }

    private var remainingColor: Color {
        if remaining < 0 { return .danger }
        if remaining < monthlyAllocation * Decimal(0.1) { return .warning }
        return .success
    }

    var body: some View {
        ZStack {
            Color.bgPrimary
                .ignoresSafeArea()

            if let envelope {
                ScrollView {
                    VStack(spacing: AppDesign.paddingLg) {
                        heroCard(envelope)
                        monthBreakdownSection
                        allocationSection(envelope)
                        if !envelope.isCCPayment {
                            dangerSection(envelope)
                        }
                    }
                    .padding(.horizontal, AppDesign.paddingLg)
                    .padding(.vertical, AppDesign.paddingMd)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.textMuted)
                    Text("Envelope not found")
                        .font(.headline)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .navigationTitle(envelope?.name ?? "Envelope")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
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

                        Divider()

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Envelope", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(LinearGradient.brand)
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
    }

    // MARK: - Hero Card

    private func heroCard(_ envelope: EnvelopeResponse) -> some View {
        VStack(spacing: 16) {
            Image(systemName: envelope.isCCPayment ? "creditcard.fill" : "envelope.fill")
                .font(.system(size: 44))
                .foregroundStyle(LinearGradient.brand)
                .shadow(color: .accentCyan.opacity(0.3), radius: 16)

            VStack(spacing: 4) {
                Text(envelope.isCCPayment ? "Available for Payment" : "Remaining")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)

                Text(formatCurrency(remaining))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(remainingColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.bgCardHover)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(remaining < 0
                              ? LinearGradient(colors: [.danger, .danger.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                              : LinearGradient.brand
                        )
                        .frame(width: max(geometry.size.width * progress, 0), height: 8)
                        .animation(.spring(duration: 0.4), value: progress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, AppDesign.paddingMd)

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
        .glassCard()
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    // MARK: - Month Breakdown

    private var monthBreakdownSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.paddingSm) {
            sectionHeader("This Month", icon: "calendar")

            VStack(spacing: 0) {
                infoRow(label: "Allocated", value: formatCurrency(monthlyAllocation), color: .textPrimary)
                Divider().overlay(Color.borderSubtle)
                infoRow(label: "Spent", value: formatCurrency(monthlySpent), color: monthlySpent > 0 ? .warning : .textSecondary)
                Divider().overlay(Color.borderSubtle)
                infoRow(label: "Net", value: formatCurrency(monthlyAllocation - monthlySpent),
                        color: monthlyAllocation - monthlySpent >= 0 ? .success : .danger)
            }
            .glassCard()
        }
    }

    // MARK: - Allocation Section

    private func allocationSection(_ envelope: EnvelopeResponse) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.paddingSm) {
            sectionHeader("Budget", icon: "dollarsign.circle.fill")

            VStack(spacing: 0) {
                infoRow(label: "All-Time Allocated", value: formatCurrency(envelope.allocatedBalance), color: .textPrimary)
                Divider().overlay(Color.borderSubtle)

                // Editable monthly allocation
                Button {
                    editedAllocation = "\(monthlyAllocation)"
                    showEditAllocation = true
                } label: {
                    HStack {
                        Text("\(envelopeService.viewedMonthString) Budget")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Text(formatCurrency(monthlyAllocation))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.accentCyan)
                            Image(systemName: "pencil.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.accentCyan.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, AppDesign.paddingMd)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if let goalType = envelope.goalType {
                    Divider().overlay(Color.borderSubtle)
                    goalRow(envelope, goalType: goalType)
                }
            }
            .glassCard()
        }
    }

    private func goalRow(_ envelope: EnvelopeResponse, goalType: GoalType) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: goalType.icon)
                        .font(.caption)
                        .foregroundStyle(Color.accentCyan)
                    Text("\(goalType.displayName) Goal")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }

                if let target = envelope.goalAmount, goalType == .target {
                    Text("Target: \(formatCurrency(target))")
                        .font(.caption)
                        .foregroundStyle(Color.textMuted)
                }
                if let monthly = envelope.monthlyGoalTarget {
                    Text("Goal: \(formatCurrency(monthly))/\(goalType == .weekly ? "wk" : "mo")")
                        .font(.caption)
                        .foregroundStyle(Color.textMuted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, AppDesign.paddingMd)
        .padding(.vertical, 12)
    }

    // MARK: - Danger Section

    private func dangerSection(_ envelope: EnvelopeResponse) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.paddingSm) {
            sectionHeader("Danger Zone", icon: "exclamationmark.triangle.fill")

            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "trash.fill")
                        .font(.title3)
                        .foregroundStyle(Color.danger)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                                .fill(Color.danger.opacity(0.1))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete Envelope")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.danger)
                        Text("Remove this envelope and all allocations")
                            .font(.caption)
                            .foregroundStyle(Color.textMuted)
                    }

                    Spacer()

                    if isDeleting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.danger)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.textMuted)
                    }
                }
                .padding(AppDesign.paddingMd)
                .background(
                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusLg)
                        .fill(Color.bgCard.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusLg)
                                .stroke(Color.danger.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(LinearGradient.brand)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)
        }
        .padding(.horizontal, 4)
    }

    private func infoRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
        .padding(.horizontal, AppDesign.paddingMd)
        .padding(.vertical, 12)
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
