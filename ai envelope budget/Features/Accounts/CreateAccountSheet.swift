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
            ZStack {
                Color.bgPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppDesign.paddingLg) {
                        // Header Icon
                        Image(systemName: accountType.icon)
                            .font(.system(size: 48))
                            .foregroundStyle(LinearGradient.brand)
                            .shadow(color: .accentCyan.opacity(0.3), radius: 16)
                            .padding(.top, AppDesign.paddingMd)
                            .animation(.spring(duration: 0.3), value: accountType)

                        // Form Fields
                        VStack(spacing: AppDesign.paddingMd) {
                            // Account Name
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Account Name")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textSecondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)

                                TextField("e.g., My Checking", text: $name)
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

                            // Account Type
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Account Type")
                                    .font(.caption)
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
                                .colorMultiply(.accentCyan)
                            }

                            // Starting Balance
                            VStack(alignment: .leading, spacing: 6) {
                                Text(accountType.isCreditCard ? "Current Balance Owed" : "Starting Balance")
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
                            }
                        }
                        .padding(.horizontal, AppDesign.paddingLg)

                        // Info
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(Color.accentCyan)
                                .font(.caption)

                            Text(accountType.isCreditCard
                                 ? "Enter the current balance owed on this card."
                                 : "Enter the current balance available in this account.")
                                .font(.caption)
                                .foregroundStyle(Color.textMuted)
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
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                    .fill(isValid ? AnyShapeStyle(LinearGradient.brand) : AnyShapeStyle(Color.textMuted.opacity(0.3)))
                            )
                            .glowShadow()
                        }
                        .disabled(!isValid || isSubmitting)
                        .padding(.horizontal, AppDesign.paddingLg)
                        .padding(.top, AppDesign.paddingSm)
                    }
                }
            }
            .navigationTitle("New Account")
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
