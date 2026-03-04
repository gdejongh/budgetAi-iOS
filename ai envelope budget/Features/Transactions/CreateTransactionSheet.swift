//
//  CreateTransactionSheet.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct CreateTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TransactionService.self) private var transactionService
    @Environment(AccountService.self) private var accountService
    @Environment(EnvelopeService.self) private var envelopeService
    @Environment(DataRefreshService.self) private var dataRefreshService

    /// Preselect an account
    var preselectedAccountId: String?

    @State private var isDeposit = false
    @State private var selectedAccountId = ""
    @State private var merchant = ""
    @State private var amount = ""
    @State private var descriptionText = ""
    @State private var transactionDate = Date()
    @State private var selectedEnvelopeId = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isAmountFocused: Bool

    private var selectedAccount: BankAccountResponse? {
        accountService.accounts.first { $0.id == selectedAccountId }
    }

    private var isCreditCard: Bool {
        selectedAccount?.resolvedType.isCreditCard ?? false
    }

    private var typeLabel: String {
        if isCreditCard {
            return isDeposit ? "Refund" : "Purchase"
        }
        return isDeposit ? "Deposit" : "Withdrawal"
    }

    private var isValid: Bool {
        !selectedAccountId.isEmpty &&
        !amount.isEmpty &&
        (Decimal(string: amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                    VStack(spacing: AppDesign.paddingLg) {
                        // Type Toggle
                        typeToggle

                        // Account Picker
                        formSection("Account") {
                            Picker("Account", selection: $selectedAccountId) {
                                Text("Select account").tag("")
                                ForEach(accountService.accounts) { account in
                                    HStack {
                                        Image(systemName: account.resolvedType.icon)
                                        Text(account.name)
                                    }
                                    .tag(account.id ?? "")
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.accentCyan)
                        }

                        // Merchant
                        formSection("Merchant") {
                            TextField("e.g. Whole Foods", text: $merchant)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.textPrimary)
                        }

                        // Amount
                        formSection("Amount") {
                            HStack {
                                Text("$")
                                    .foregroundStyle(Color.textSecondary)
                                TextField("0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .focused($isAmountFocused)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(Color.textPrimary)
                            }
                        }

                        // Description
                        formSection("Description (optional)") {
                            TextField("Add a note", text: $descriptionText)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.textPrimary)
                        }

                        // Date
                        formSection("Date") {
                            DatePicker(
                                "Date",
                                selection: $transactionDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(.accentCyan)
                        }

                        // Envelope
                        formSection("Envelope (optional)") {
                            Picker("Envelope", selection: $selectedEnvelopeId) {
                                Text("None").tag("")
                                ForEach(envelopeService.envelopes.filter { !$0.isCCPayment }) { env in
                                    Text(env.name).tag(env.id ?? "")
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.accentCyan)
                        }

                        // Error
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Color.danger)
                                .padding(.horizontal, AppDesign.paddingSm)
                        }

                        // Submit
                        Button {
                            Task { await save() }
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Text("Add \(typeLabel)")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!isValid || isSaving)
                    }
                    .padding(AppDesign.paddingLg)
            }
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                KeyboardDoneToolbar {
                    isAmountFocused = false
                }
            }
            .onAppear {
                if let preId = preselectedAccountId, !preId.isEmpty {
                    selectedAccountId = preId
                } else if let first = accountService.accounts.first {
                    selectedAccountId = first.id ?? ""
                }
            }
        }
    }

    // MARK: - Type Toggle

    private var typeToggle: some View {
        HStack(spacing: 0) {
            toggleButton(
                label: isCreditCard ? "Purchase" : "Withdrawal",
                icon: "arrow.up.right",
                isSelected: !isDeposit
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { isDeposit = false }
            }

            toggleButton(
                label: isCreditCard ? "Refund" : "Deposit",
                icon: "arrow.down.left",
                isSelected: isDeposit
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { isDeposit = true }
            }
        }
    }

    private func toggleButton(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? Color.textPrimary : Color.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                    .fill(isSelected ? Color.bgCardHover : Color.clear)
            )
        }
        .padding(4)
    }

    // MARK: - Form Section

    private func formSection<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)

            content()
                .formFieldBackground()
        }
    }

    // MARK: - Save

    private func save() async {
        guard let decimalAmount = Decimal(string: amount), decimalAmount > 0 else { return }
        isSaving = true
        errorMessage = nil

        // Sign the amount: withdrawals/purchases are negative, deposits/refunds are positive
        let signedAmount = isDeposit ? decimalAmount : -decimalAmount

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: transactionDate)

        let success = await transactionService.createTransaction(
            bankAccountId: selectedAccountId,
            envelopeId: selectedEnvelopeId.isEmpty ? nil : selectedEnvelopeId,
            amount: signedAmount,
            description: descriptionText.isEmpty ? nil : descriptionText,
            merchantName: merchant.isEmpty ? nil : merchant,
            transactionDate: dateStr
        )

        if success {
            await dataRefreshService.refreshAfterTransactionChange()
            dismiss()
        } else {
            errorMessage = transactionService.errorMessage ?? "Failed to create transaction."
        }
        isSaving = false
    }
}

#Preview {
    CreateTransactionSheet()
        .environment(TransactionService())
        .environment(AccountService())
        .environment(EnvelopeService())
        .environment(DataRefreshService(accountService: AccountService(), envelopeService: EnvelopeService(), transactionService: TransactionService()))
}
