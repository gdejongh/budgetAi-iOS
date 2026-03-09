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
    @State private var isAmountEditing = false

    init(account: BankAccountResponse) {
        self.account = account
        self._name = State(initialValue: account.name)
        self._balanceText = State(
            initialValue: "\(account.currentBalance)"
        )
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && parsedBalance != nil
    }

    private var hasChanges: Bool {
        let nameChanged = name.trimmingCharacters(in: .whitespaces) != account.name
        let balanceChanged = parsedBalance != account.currentBalance
        return nameChanged || balanceChanged
    }

    private var parsedBalance: Decimal? {
        let trimmed = balanceText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return Decimal.zero }
        return evaluateMathExpression(trimmed)
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

                        // Balance
                        VStack(alignment: .leading, spacing: 6) {
                            Text(accountType.isCreditCard ? "Balance Owed" : "Current Balance")
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

                                Text(balanceText.isEmpty ? "0.00" : balanceText)
                                    .font(.appTitle)
                                    .foregroundStyle(balanceText.isEmpty ? Color.textMuted : Color.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        isAmountEditing = true
                                    }
                            }
                            .formFieldBackground()
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.accentCyan, lineWidth: isAmountEditing ? 2 : 0)
                            )
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
            .calculatorKeypadInput(text: $balanceText, isEditing: $isAmountEditing)
            .navigationTitle("Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                KeyboardDoneToolbar {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
        let balance = parsedBalance ?? account.currentBalance
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
