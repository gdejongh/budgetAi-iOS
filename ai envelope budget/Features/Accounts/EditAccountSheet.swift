//
//  EditAccountSheet.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct EditAccountSheet: View {
    @Environment(AccountService.self) private var accountService
    @Environment(\.dismiss) private var dismiss

    let account: BankAccountResponse

    @State private var name: String
    @State private var balanceText: String
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    init(account: BankAccountResponse) {
        self.account = account
        self._name = State(initialValue: account.name)
        self._balanceText = State(
            initialValue: "\(account.currentBalance)"
        )
    }

    private var isManual: Bool {
        account.manual == true || account.manual == nil
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (isManual ? parsedBalance != nil : true)
    }

    private var hasChanges: Bool {
        let nameChanged = name.trimmingCharacters(in: .whitespaces) != account.name
        let balanceChanged = isManual && parsedBalance != account.currentBalance
        return nameChanged || balanceChanged
    }

    private var parsedBalance: Decimal? {
        let cleaned = balanceText
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { return Decimal.zero }
        return Decimal(string: cleaned)
    }

    private var accountType: AccountType {
        account.resolvedType
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppDesign.paddingLg) {
                        // Header icon
                        Image(systemName: accountType.icon)
                            .font(.system(size: 44))
                            .foregroundStyle(LinearGradient.brand)
                            .shadow(color: .accentCyan.opacity(0.3), radius: 16)
                            .padding(.top, AppDesign.paddingMd)

                        VStack(spacing: AppDesign.paddingMd) {
                            // Account Name
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Account Name")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textSecondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)

                                TextField("Account name", text: $name)
                                    .textFieldStyle(.plain)
                                    .padding(AppDesign.paddingSm + 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                            .fill(Color.bgInput)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                                    .stroke(Color.borderSubtle, lineWidth: 1)
                                            )
                                    )
                                    .foregroundStyle(Color.textPrimary)
                                    .autocorrectionDisabled()
                            }

                            // Balance (editable for manual, read-only for Plaid)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(accountType.isCreditCard ? "Balance Owed" : "Current Balance")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.textSecondary)
                                        .textCase(.uppercase)
                                        .tracking(0.5)

                                    if !isManual {
                                        Text("· Plaid Managed")
                                            .font(.caption2)
                                            .foregroundStyle(Color.accentCyan)
                                    }
                                }

                                if isManual {
                                    HStack {
                                        Text("$")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.textSecondary)

                                        TextField("0.00", text: $balanceText)
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
                                } else {
                                    HStack {
                                        Text(formatCurrency(account.currentBalance))
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.textMuted)
                                        Spacer()
                                    }
                                    .padding(AppDesign.paddingSm + 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                            .fill(Color.bgCard.opacity(0.5))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                                    .stroke(Color.borderSubtle, lineWidth: 1)
                                            )
                                    )
                                }
                            }

                            // Info about account type (read-only)
                            HStack {
                                Text("Account Type")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textSecondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                Spacer()
                                Text(accountType.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.textPrimary)
                            }
                            .padding(AppDesign.paddingSm + 4)
                            .background(
                                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                    .fill(Color.bgCard.opacity(0.5))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                            .stroke(Color.borderSubtle, lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, AppDesign.paddingLg)

                        // Note for Plaid accounts
                        if !isManual {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(Color.accentCyan)
                                    .font(.caption)
                                Text("Balance is synced from your bank via Plaid and cannot be edited directly.")
                                    .font(.caption)
                                    .foregroundStyle(Color.textMuted)
                            }
                            .padding(.horizontal, AppDesign.paddingLg)
                        }

                        // Save Button
                        Button {
                            Task { await saveChanges() }
                        } label: {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text("Save Changes")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                    .fill(isValid && hasChanges
                                          ? AnyShapeStyle(LinearGradient.brand)
                                          : AnyShapeStyle(Color.textMuted.opacity(0.3)))
                            )
                            .glowShadow()
                        }
                        .disabled(!isValid || !hasChanges || isSubmitting)
                        .padding(.horizontal, AppDesign.paddingLg)
                        .padding(.top, AppDesign.paddingSm)
                    }
                }
            }
            .navigationTitle("Edit Account")
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

    private func saveChanges() async {
        let balance = isManual ? (parsedBalance ?? account.currentBalance) : account.currentBalance
        isSubmitting = true

        let success = await accountService.updateAccount(
            account,
            name: name.trimmingCharacters(in: .whitespaces),
            balance: balance
        )

        if success {
            dismiss()
        } else {
            errorMessage = accountService.errorMessage ?? "Failed to save changes."
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
}
