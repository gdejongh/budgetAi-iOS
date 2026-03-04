//
//  TransferSheet.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct TransferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TransactionService.self) private var transactionService
    @Environment(AccountService.self) private var accountService

    /// Preselect a source account
    var preselectedSourceId: String?

    @State private var sourceAccountId = ""
    @State private var destinationAccountId = ""
    @State private var amount = ""
    @State private var descriptionText = ""
    @State private var transactionDate = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isAmountFocused: Bool

    private var isValid: Bool {
        !sourceAccountId.isEmpty &&
        !destinationAccountId.isEmpty &&
        sourceAccountId != destinationAccountId &&
        !amount.isEmpty &&
        (Decimal(string: amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                    VStack(spacing: AppDesign.paddingLg) {
                        // Transfer Icon
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.accentColor)
                            Spacer()
                        }
                        .padding(.vertical, AppDesign.paddingSm)

                        // From Account
                        formSection("From Account") {
                            Picker("Source", selection: $sourceAccountId) {
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

                        // Swap button
                        if !sourceAccountId.isEmpty && !destinationAccountId.isEmpty {
                            Button {
                                let tmp = sourceAccountId
                                sourceAccountId = destinationAccountId
                                destinationAccountId = tmp
                            } label: {
                                Image(systemName: "arrow.up.arrow.down.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.accentCyan)
                            }
                        }

                        // To Account
                        formSection("To Account") {
                            Picker("Destination", selection: $destinationAccountId) {
                                Text("Select account").tag("")
                                ForEach(accountService.accounts.filter { $0.id != sourceAccountId }) { account in
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
                            TextField("e.g. Savings transfer", text: $descriptionText)
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

                        // Same account warning
                        if !sourceAccountId.isEmpty && sourceAccountId == destinationAccountId {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.warning)
                                Text("Source and destination must be different accounts.")
                                    .font(.caption)
                                    .foregroundStyle(Color.warning)
                            }
                        }

                        // Error
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
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
                                        Image(systemName: "arrow.triangle.swap")
                                        Text("Transfer")
                                    }
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
            .navigationTitle("Transfer")
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
                if let preId = preselectedSourceId, !preId.isEmpty {
                    sourceAccountId = preId
                } else if let first = accountService.accounts.first {
                    sourceAccountId = first.id ?? ""
                }
            }
        }
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

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: transactionDate)

        let success = await transactionService.createTransfer(
            sourceAccountId: sourceAccountId,
            destinationAccountId: destinationAccountId,
            amount: decimalAmount,
            merchantName: nil,
            description: descriptionText.isEmpty ? nil : descriptionText,
            transactionDate: dateStr
        )

        if success {
            await accountService.fetchAccounts()
            dismiss()
        } else {
            errorMessage = transactionService.errorMessage ?? "Failed to create transfer."
        }
        isSaving = false
    }
}

#Preview {
    TransferSheet()
        .environment(TransactionService())
        .environment(AccountService())
}
