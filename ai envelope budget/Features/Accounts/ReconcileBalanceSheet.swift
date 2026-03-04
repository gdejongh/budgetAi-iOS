//
//  ReconcileBalanceSheet.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct ReconcileBalanceSheet: View {
    @Environment(AccountService.self) private var accountService
    @Environment(\.dismiss) private var dismiss

    let account: BankAccountResponse

    @State private var targetBalanceText = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var parsedBalance: Decimal? {
        let cleaned = targetBalanceText
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { return nil }
        return Decimal(string: cleaned)
    }

    private var isValid: Bool {
        guard let balance = parsedBalance else { return false }
        return balance >= 0
    }

    private var difference: Decimal? {
        guard let target = parsedBalance else { return nil }
        return target - account.currentBalance
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppDesign.paddingLg) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 44))
                                .foregroundStyle(LinearGradient.brand)
                                .shadow(color: .accentCyan.opacity(0.3), radius: 16)

                            Text("Reconcile Balance")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.textPrimary)

                            Text(account.name)
                                .font(.subheadline)
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(.top, AppDesign.paddingMd)

                        // Current balance display
                        VStack(spacing: 4) {
                            Text("Current Balance")
                                .font(.caption)
                                .foregroundStyle(Color.textMuted)
                            Text(formatCurrency(account.currentBalance))
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(AppDesign.paddingMd)
                        .glassCard()
                        .padding(.horizontal, AppDesign.paddingLg)

                        // Target balance input
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Actual Balance")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            HStack {
                                Text("$")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textSecondary)

                                TextField("0.00", text: $targetBalanceText)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.decimalPad)
                                    .foregroundStyle(Color.textPrimary)
                                    .font(.title3)
                            }
                            .padding(AppDesign.paddingSm + 4)
                            .background(
                                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                    .fill(Color.bgInput)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                            .stroke(Color.borderSubtle, lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, AppDesign.paddingLg)

                        // Difference preview
                        if let diff = difference {
                            VStack(spacing: 4) {
                                Text("Adjustment")
                                    .font(.caption)
                                    .foregroundStyle(Color.textMuted)

                                HStack(spacing: 4) {
                                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                                        .font(.caption)
                                    Text(formatCurrency(abs(diff)))
                                }
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(diff >= 0 ? Color.success : Color.danger)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(AppDesign.paddingMd)
                            .glassCard()
                            .padding(.horizontal, AppDesign.paddingLg)
                            .animation(.spring(duration: 0.3), value: diff)
                        }

                        // Info
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(Color.accentCyan)
                                .font(.caption)
                            Text("This will create an adjustment transaction to match the actual balance.")
                                .font(.caption)
                                .foregroundStyle(Color.textMuted)
                        }
                        .padding(.horizontal, AppDesign.paddingLg)

                        // Submit button
                        Button {
                            Task { await reconcile() }
                        } label: {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text("Reconcile")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                    .fill(isValid
                                          ? AnyShapeStyle(LinearGradient.brand)
                                          : AnyShapeStyle(Color.textMuted.opacity(0.3)))
                            )
                            .glowShadow()
                        }
                        .disabled(!isValid || isSubmitting)
                        .padding(.horizontal, AppDesign.paddingLg)
                        .padding(.top, AppDesign.paddingSm)
                    }
                }
            }
            .navigationTitle("Adjust Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.textSecondary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Actions

    private func reconcile() async {
        guard let target = parsedBalance else { return }
        isSubmitting = true

        let success = await accountService.reconcileAccount(account, targetBalance: target)

        if success {
            dismiss()
        } else {
            errorMessage = accountService.errorMessage ?? "Failed to reconcile balance."
            showError = true
        }

        isSubmitting = false
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

    private func abs(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }
}
