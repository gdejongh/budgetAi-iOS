//
//  CCPaymentSheet.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct CCPaymentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TransactionService.self) private var transactionService
    @Environment(AccountService.self) private var accountService
    @Environment(DataRefreshService.self) private var dataRefreshService

    /// The credit card to pay
    let creditCard: BankAccountResponse

    @State private var selectedBankAccountId = ""
    @State private var amount = ""
    @State private var descriptionText = ""
    @State private var transactionDate = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isAmountEditing = false

    private var bankAccounts: [BankAccountResponse] {
        accountService.bankAccounts
    }

    private var isValid: Bool {
        !selectedBankAccountId.isEmpty &&
        !amount.isEmpty &&
        (evaluateMathExpression(amount).map { $0 > 0 } ?? false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppDesign.paddingLg) {
                    // Credit Card Info Header
                    ccInfoCard

                    // Pay From
                    formSection("Pay From") {
                        Picker("Bank Account", selection: $selectedBankAccountId) {
                            Text("Select bank account").tag("")
                            ForEach(bankAccounts) { account in
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

                    // Amount
                    formSection("Payment Amount") {
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

                            Spacer()

                            // Pay full balance shortcut
                            if creditCard.currentBalance > 0 {
                                Button {
                                    amount = "\(creditCard.currentBalance)"
                                } label: {
                                    Text("Pay Full")
                                        .font(.appCaption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.accentCyan)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule().fill(Color.accentCyan.opacity(0.15))
                                        )
                                }
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentCyan, lineWidth: isAmountEditing ? 2 : 0)
                    )

                    // Description
                    formSection("Description (optional)") {
                        TextField("e.g. Monthly CC payment", text: $descriptionText)
                            .textFieldStyle(.plain)
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

                    // Error
                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundStyle(Color.danger)
                    }

                    // Submit
                    Button {
                        Task { await save() }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView()
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "creditcard.fill")
                                    Text("Make Payment")
                                }
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
            .navigationTitle("CC Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                KeyboardDoneToolbar {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .onAppear {
                if let first = bankAccounts.first {
                    selectedBankAccountId = first.id ?? ""
                }
            }
        }
    }

    // MARK: - CC Info Card

    private var ccInfoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "creditcard.fill")
                .font(.title2)
                .foregroundStyle(Color.accentCyan)

            VStack(alignment: .leading, spacing: 2) {
                Text(creditCard.name)
                    .font(.appHeadline)

                Text("Balance owed: \(creditCard.currentBalance.asCurrency())")
                    .font(.appCaption)
                    .foregroundStyle(Color.warning)
            }

            Spacer()
        }
        .padding(AppDesign.paddingMd)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Form Section

    private func formSection<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .formFieldBackground()
        }
    }

    // MARK: - Save

    private func save() async {
        guard let decimalAmount = evaluateMathExpression(amount), decimalAmount > 0 else { return }
        guard let ccId = creditCard.id else { return }
        isSaving = true
        errorMessage = nil

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: transactionDate)

        let success = await transactionService.createCCPayment(
            bankAccountId: selectedBankAccountId,
            creditCardId: ccId,
            amount: decimalAmount,
            description: descriptionText.isEmpty ? nil : descriptionText,
            transactionDate: dateStr
        )

        if success {
            await dataRefreshService.refreshAfterCCPayment()
            dismiss()
        } else {
            errorMessage = transactionService.errorMessage ?? "Failed to process payment."
        }
        isSaving = false
    }
}

#Preview {
    CCPaymentSheet(
        creditCard: BankAccountResponse(
            id: "cc1", appUserId: "u1", name: "Chase Sapphire", accountType: .creditCard,
            currentBalance: 1250.00, plaidAccountId: nil, plaidItemId: nil,
            accountMask: "4321", manual: true, institutionName: nil, plaidLinkedAt: nil, createdAt: nil
        )
    )
    .environment(TransactionService())
    .environment(AccountService())
    .environment(DataRefreshService(accountService: AccountService(), envelopeService: EnvelopeService(), transactionService: TransactionService()))
}
