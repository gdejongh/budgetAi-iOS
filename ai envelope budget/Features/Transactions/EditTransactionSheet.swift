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
        (Decimal(string: amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

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
                            .colorScheme(.dark)
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
                                        .tint(.white)
                                } else {
                                    Text("Save Changes")
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                    .fill(isValid ? LinearGradient.brand : LinearGradient(colors: [.textMuted], startPoint: .leading, endPoint: .trailing))
                            )
                            .glowShadow()
                        }
                        .disabled(!isValid || isSaving)
                    }
                    .padding(AppDesign.paddingLg)
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
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
        .glassCard(cornerRadius: AppDesign.cornerRadiusMd)
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
                .padding(AppDesign.paddingSm + 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                        .fill(Color.bgInput)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                                .stroke(Color.borderSubtle, lineWidth: 1)
                        )
                )
        }
    }

    // MARK: - Save

    private func save() async {
        guard let decimalAmount = Decimal(string: amount), decimalAmount > 0 else { return }
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
            await accountService.fetchAccounts()
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
}
