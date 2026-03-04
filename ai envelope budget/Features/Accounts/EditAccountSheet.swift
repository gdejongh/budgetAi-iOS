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

    @FocusState private var isBalanceFocused: Bool

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
            ScrollView {
                VStack(spacing: AppDesign.paddingLg) {
                    // Header icon
                    Image(systemName: accountType.icon)
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentCyan)
                        .padding(.top, AppDesign.paddingMd)

                    VStack(spacing: AppDesign.paddingMd) {
                        // Account Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Account Name")
                                .font(.appCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            TextField("Account name", text: $name)
                                .textFieldStyle(.plain)
                                .formFieldBackground()
                                .autocorrectionDisabled()
                        }

                        // Balance (editable for manual, read-only for Plaid)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(accountType.isCreditCard ? "Balance Owed" : "Current Balance")
                                    .font(.appCaption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textSecondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)

                                if !isManual {
                                    Text("· Plaid Managed")
                                        .font(.appCaption)
                                        .foregroundStyle(Color.accentCyan)
                                }
                            }

                            if isManual {
                                HStack {
                                    Text("$")
                                        .font(.appTitle)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.textSecondary)

                                    TextField("0.00", text: $balanceText)
                                        .textFieldStyle(.plain)
                                        .keyboardType(.decimalPad)
                                        .font(.appTitle)
                                        .focused($isBalanceFocused)
                                }
                                .formFieldBackground()
                            } else {
                                HStack {
                                    Text(account.currentBalance.asCurrency())
                                        .font(.appTitle)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.textSecondary)
                                    Spacer()
                                }
                                .padding(AppDesign.paddingSm + 4)
                                .background(
                                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                            }
                        }

                        // Info about account type (read-only)
                        HStack {
                            Text("Account Type")
                                .font(.appCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Spacer()
                            Text(accountType.displayName)
                                .font(.appBody)
                                .fontWeight(.medium)
                        }
                        .padding(AppDesign.paddingSm + 4)
                        .background(
                            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }
                    .padding(.horizontal, AppDesign.paddingLg)

                    // Note for Plaid accounts
                    if !isManual {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(Color.accentCyan)
                                .font(.appCaption)
                            Text("Balance is synced from your bank via Plaid and cannot be edited directly.")
                                .font(.appCaption)
                                .foregroundStyle(Color.textSecondary)
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
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .controlSize(.large)
                    .disabled(!isValid || !hasChanges || isSubmitting)
                    .padding(.horizontal, AppDesign.paddingLg)
                    .padding(.top, AppDesign.paddingSm)
                }
            }
            .navigationTitle("Edit Account")
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
}
