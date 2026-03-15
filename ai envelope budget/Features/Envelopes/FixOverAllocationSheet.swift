//
//  FixOverAllocationSheet.swift
//  ai envelope budget
//

import SwiftUI

struct FixOverAllocationSheet: View {
    @Environment(EnvelopeService.self) private var envelopeService
    @Environment(AccountService.self) private var accountService
    @Environment(TransactionService.self) private var transactionService
    @Environment(\.dismiss) private var dismiss

    // Local draft: envelopeId -> new allocation amount
    @State private var drafts: [String: Decimal] = [:]
    @State private var editingEnvelopeId: String?
    @State private var editedAllocation = ""
    @State private var isSaving = false

    private var nonCCEnvelopes: [EnvelopeResponse] {
        envelopeService.envelopes.filter { !$0.isCCPayment }
    }

    private var currentUnallocated: Decimal {
        let totalCash = accountService.accounts
            .filter { !$0.resolvedType.isCreditCard }
            .reduce(Decimal.zero) { $0 + $1.currentBalance }
        let totalAllTimeSpent = transactionService.transactions
            .filter { $0.envelopeId != nil }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let totalAllocated = envelopeService.envelopes.reduce(Decimal.zero) { sum, env in
            let draft = drafts[env.id ?? ""]
            let base = envelopeService.monthlyAllocation(for: env)
            return sum + (draft ?? base)
        }
        return totalCash - totalAllocated - totalAllTimeSpent
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Pinned unallocated header
                VStack(spacing: 4) {
                    Text("Unallocated")
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                    Text(currentUnallocated.asCurrency())
                        .font(.appStatLarge)
                        .foregroundStyle(currentUnallocated < 0 ? Color.danger : Color.success)
                    if currentUnallocated < 0 {
                        Text("Allocated too much")
                            .font(.appCaption)
                            .foregroundStyle(Color.danger)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.bgSurface)

                Divider()

                // Envelope list
                List {
                    ForEach(nonCCEnvelopes) { envelope in
                        let current = drafts[envelope.id ?? ""] ?? envelopeService.monthlyAllocation(for: envelope)
                        let isEditing = editingEnvelopeId == envelope.id

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(envelope.name)
                                    .font(.appBody)
                                    .foregroundStyle(Color.textPrimary)
                                Text("Spent: \(envelopeService.monthlySpent(for: envelope).asCurrency())")
                                    .font(.appCaption)
                                    .foregroundStyle(Color.textSecondary)
                            }

                            Spacer()

                            if isEditing {
                                Text(editedAllocation.isEmpty ? "0" : editedAllocation)
                                    .font(.appBody)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.accentCyan)
                                    .frame(minWidth: 80, alignment: .trailing)
                            } else {
                                Text(current.asCurrency())
                                    .font(.appBody)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textPrimary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if editingEnvelopeId == envelope.id { return }
                            if let prev = editingEnvelopeId {
                                commitDraft(for: prev)
                            }
                            editedAllocation = "\(drafts[envelope.id ?? ""] ?? envelopeService.monthlyAllocation(for: envelope))"
                            editingEnvelopeId = envelope.id
                        }
                    }
                }
                .listStyle(.plain)

                Divider()

                // Save button
                Button {
                    Task { await saveAll() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Save Allocations")
                                .font(.appBody)
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentCyan)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .disabled(isSaving)
            }
            .navigationTitle("Fix Allocations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.accentCyan)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if editingEnvelopeId != nil {
                    CalculatorKeypad(
                        text: $editedAllocation,
                        onDone: {
                            if let id = editingEnvelopeId { commitDraft(for: id) }
                            editingEnvelopeId = nil
                        },
                        onCancel: {
                            editingEnvelopeId = nil
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: editingEnvelopeId != nil)
        }
    }

    private func commitDraft(for id: String) {
        guard let value = evaluateMathExpression(editedAllocation), value >= 0 else { return }
        drafts[id] = value
    }

    private func saveAll() async {
        // Commit any open edit first
        if let id = editingEnvelopeId {
            commitDraft(for: id)
            editingEnvelopeId = nil
        }

        guard !drafts.isEmpty else { dismiss(); return }

        isSaving = true
        for (envelopeId, amount) in drafts {
            guard let envelope = envelopeService.envelopes.first(where: { $0.id == envelopeId }) else { continue }
            _ = await envelopeService.setAllocation(for: envelope, amount: amount)
        }
        isSaving = false
        dismiss()
    }
}
