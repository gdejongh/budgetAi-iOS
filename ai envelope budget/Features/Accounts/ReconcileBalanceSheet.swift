//
//  ReconcileBalanceSheet.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct ReconcileBalanceSheet: View {
    @Environment(AccountService.self) private var accountService
    @Environment(DataRefreshService.self) private var dataRefreshService
    @Environment(\.dismiss) private var dismiss

    let account: BankAccountResponse

    @State private var targetBalanceText = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    @FocusState private var isBalanceFocused: Bool

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
            ScrollView {
                VStack(spacing: AppDesign.paddingLg) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentCyan)

                        Text("Reconcile Balance")
                            .font(.appTitle)
                            .fontWeight(.bold)

                        Text(account.name)
                            .font(.appBody)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.top, AppDesign.paddingMd)

                    // Current balance display
                    VStack(spacing: 4) {
                        Text("Current Balance")
                            .font(.appCaption)
                            .foregroundStyle(Color.textSecondary)
                        Text(account.currentBalance.asCurrency())
                            .font(.appStatLarge)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppDesign.paddingMd)
                    .background(
                        RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .padding(.horizontal, AppDesign.paddingLg)

                    // Target balance input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Actual Balance")
                            .font(.appCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        HStack {
                            Text("$")
                                .font(.appTitle)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.textSecondary)

                            TextField("0.00", text: $targetBalanceText)
                                .textFieldStyle(.plain)
                                .keyboardType(.decimalPad)
                                .font(.appTitle)
                                .focused($isBalanceFocused)
                        }
                        .formFieldBackground()
                    }
                    .padding(.horizontal, AppDesign.paddingLg)

                    // Difference preview
                    if let diff = difference {
                        VStack(spacing: 4) {
                            Text("Adjustment")
                                .font(.appCaption)
                                .foregroundStyle(Color.textSecondary)

                            HStack(spacing: 4) {
                                Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.appCaption)
                                Text(abs(diff).asCurrency())
                            }
                            .font(.appHeadline)
                            .foregroundStyle(diff >= 0 ? Color.success : Color.danger)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(AppDesign.paddingMd)
                        .background(
                            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .padding(.horizontal, AppDesign.paddingLg)
                        .animation(.spring(duration: 0.3), value: diff)
                    }

                    // Info
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.accentCyan)
                            .font(.appCaption)
                        Text("This will create an adjustment transaction to match the actual balance.")
                            .font(.appCaption)
                            .foregroundStyle(Color.textSecondary)
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
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .controlSize(.large)
                    .disabled(!isValid || isSubmitting)
                    .padding(.horizontal, AppDesign.paddingLg)
                    .padding(.top, AppDesign.paddingSm)
                }
            }
            .navigationTitle("Adjust Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                KeyboardDoneToolbar {
                    isBalanceFocused = false
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
            await dataRefreshService.refreshAfterReconcile()
            dismiss()
        } else {
            errorMessage = accountService.errorMessage ?? "Failed to reconcile balance."
            showError = true
        }

        isSubmitting = false
    }

    // MARK: - Helpers

    private func abs(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }
}
