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

    @FocusState private var isBalanceFocused: Bool

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedBalance != nil
    }

    private var parsedBalance: Decimal? {
        let cleaned = balanceText
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { return Decimal.zero }
        return Decimal(string: cleaned)
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

                                TextField("0.00", text: $balanceText)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.decimalPad)
                                    .font(.appTitle)
                                    .focused($isBalanceFocused)
                            }
                            .formFieldBackground()
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
            .navigationTitle("New Account")
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
