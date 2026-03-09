//
//  CreateAccountSheet.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct CreateAccountSheet: View {
    @Environment(AccountService.self) private var accountService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var accountType: AccountType = .checking
    @State private var balanceText = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isAmountEditing = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedBalance != nil
    }

    private var parsedBalance: Decimal? {
        let trimmed = balanceText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return Decimal.zero }
        return evaluateMathExpression(trimmed)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppDesign.paddingLg) {
                    // Header Icon
                    Image(systemName: accountType.icon)
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentCyan)
                        .padding(.top, AppDesign.paddingMd)
                        .animation(.spring(duration: 0.3), value: accountType)

                    // Form Fields
                    VStack(spacing: AppDesign.paddingMd) {
                        // Account Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Account Name")
                                .font(.appCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            TextField("e.g., My Checking", text: $name)
                                .textFieldStyle(.plain)
                                .formFieldBackground()
                                .autocorrectionDisabled()
                        }

                        // Account Type
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Account Type")
                                .font(.appCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            Picker("Account Type", selection: $accountType) {
                                ForEach(AccountType.allCases) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Starting Balance
                        VStack(alignment: .leading, spacing: 6) {
                            Text(accountType.isCreditCard ? "Current Balance Owed" : "Starting Balance")
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
                    }
                    .padding(.horizontal, AppDesign.paddingLg)

                    // Info
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.accentCyan)
                            .font(.appCaption)

                        Text(accountType.isCreditCard
                             ? "Enter the current balance owed on this card."
                             : "Enter the current balance available in this account.")
                            .font(.appCaption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.horizontal, AppDesign.paddingLg)

                    // Create Button
                    Button {
                        Task { await createAccount() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text("Create Account")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .controlSize(.large)
                    .disabled(!isValid || isSubmitting)
                    .padding(.horizontal, AppDesign.paddingLg)
                    .padding(.top, AppDesign.paddingSm)
                }
            }
            .calculatorKeypadInput(text: $balanceText, isEditing: $isAmountEditing)
            .navigationTitle("New Account")
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

    private func createAccount() async {
        guard let balance = parsedBalance else { return }

        isSubmitting = true
        let success = await accountService.createAccount(
            name: name.trimmingCharacters(in: .whitespaces),
            type: accountType,
            balance: balance
        )

        if success {
            dismiss()
        } else {
            errorMessage = accountService.errorMessage ?? "Failed to create account."
            showError = true
        }

        isSubmitting = false
    }
}

#Preview {
    CreateAccountSheet()
        .environment(AccountService())
}
