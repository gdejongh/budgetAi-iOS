//
//  EditTransactionSheet.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct EditTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TransactionService.self) private var transactionService
    @Environment(AccountService.self) private var accountService
    @Environment(EnvelopeService.self) private var envelopeService
    @Environment(DataRefreshService.self) private var dataRefreshService

    let transaction: TransactionResponse

    @State private var isDeposit: Bool
    @State private var selectedAccountId: String
    @State private var merchant: String
    @State private var amount: String
    @State private var descriptionText: String
    @State private var transactionDate: Date
    @State private var selectedEnvelopeId: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isAmountEditing = false

    init(transaction: TransactionResponse) {
        self.transaction = transaction
        let absAmount = transaction.amount < 0 ? -transaction.amount : transaction.amount
        _isDeposit = State(initialValue: transaction.amount > 0)
        _selectedAccountId = State(initialValue: transaction.bankAccountId ?? "")
        _merchant = State(initialValue: transaction.merchantName ?? "")
        _amount = State(initialValue: "\(absAmount)")
        _descriptionText = State(initialValue: transaction.description ?? "")
        _transactionDate = State(initialValue: transaction.parsedDate ?? Date())
        _selectedEnvelopeId = State(initialValue: transaction.envelopeId ?? "")
    }

    private var selectedAccount: BankAccountResponse? {
        accountService.accounts.first { $0.id == selectedAccountId }
    }

    private var isCreditCard: Bool {
        selectedAccount?.resolvedType.isCreditCard ?? false
    }

    private var isValid: Bool {
        !selectedAccountId.isEmpty &&
        !amount.isEmpty &&
        (evaluateMathExpression(amount).map { $0 > 0 } ?? false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                    VStack(spacing: AppDesign.paddingLg) {
                        // Linked transaction info banner
                        if transaction.linkedTransactionId != nil {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                    .font(.appCaption)
                                    .foregroundStyle(Color.accentCyan)
                                Text("Changes will also update the linked transaction.")
                                    .font(.appCaption)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            .padding(AppDesign.paddingSm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                                    .fill(Color.accentCyan.opacity(0.1))
                            )
                        }

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
                                Text(amount.isEmpty ? "0.00" : amount)
                                    .foregroundStyle(amount.isEmpty ? Color.textMuted : Color.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        isAmountEditing = true
                                    }
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentCyan, lineWidth: isAmountEditing ? 2 : 0)
                        )

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
                                .font(.appCaption)
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
                                    Text("Save Changes")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .controlSize(.large)
                        .disabled(!isValid || isSaving)
                    }
                    .padding(AppDesign.paddingLg)
            }
            .calculatorKeypadInput(text: $amount, isEditing: $isAmountEditing)
            .navigationTitle(transaction.resolvedType == .ccPayment ? "Edit CC Payment" :
                            transaction.resolvedType == .transfer ? "Edit Transfer" :
                            "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                KeyboardDoneToolbar {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                    .font(.appCaption)
                Text(label)
                    .font(.appBody)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? Color.textPrimary : Color.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                    .fill(isSelected ? Color(.systemFill) : Color.clear)
            )
        }
        .padding(4)
    }

    // MARK: - Form Section

    private func formSection<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)

            content()
                .formFieldBackground()
        }
    }

    // MARK: - Save

    private func save() async {
        guard let decimalAmount = evaluateMathExpression(amount), decimalAmount > 0 else { return }
        isSaving = true
        errorMessage = nil

        let signedAmount = isDeposit ? decimalAmount : -decimalAmount

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: transactionDate)

        let success = await transactionService.updateTransaction(
            transaction,
            bankAccountId: selectedAccountId,
            envelopeId: selectedEnvelopeId.isEmpty ? nil : selectedEnvelopeId,
            amount: signedAmount,
            description: descriptionText.isEmpty ? nil : descriptionText,
            merchantName: merchant.isEmpty ? nil : merchant,
            transactionDate: dateStr
        )

        if success {
            // Also update linked transaction (CC payments & transfers)
            if let linkedId = transaction.linkedTransactionId,
               let linkedTxn = transactionService.transactions.first(where: { $0.id == linkedId }) {
                let linkedAmount = -signedAmount
                _ = await transactionService.updateTransaction(
                    linkedTxn,
                    bankAccountId: linkedTxn.bankAccountId ?? "",
                    envelopeId: linkedTxn.envelopeId,
                    amount: linkedAmount,
                    description: descriptionText.isEmpty ? nil : descriptionText,
                    merchantName: merchant.isEmpty ? nil : merchant,
                    transactionDate: dateStr
                )
            }
            await dataRefreshService.refreshAfterTransactionChange()
            dismiss()
        } else {
            errorMessage = transactionService.errorMessage ?? "Failed to update transaction."
        }
        isSaving = false
    }
}

#Preview {
    EditTransactionSheet(
        transaction: TransactionResponse(
            id: "1", appUserId: "u1", bankAccountId: "a1", envelopeId: nil,
            amount: -42.50, description: "Groceries", transactionDate: "2026-03-01",
            transactionType: "STANDARD", linkedTransactionId: nil, createdAt: nil,
            pending: false, merchantName: "Whole Foods", plaidCategory: nil, plaidTransactionId: nil
        )
    )
    .environment(TransactionService())
    .environment(AccountService())
    .environment(EnvelopeService())
    .environment(DataRefreshService(accountService: AccountService(), envelopeService: EnvelopeService(), transactionService: TransactionService()))
}
