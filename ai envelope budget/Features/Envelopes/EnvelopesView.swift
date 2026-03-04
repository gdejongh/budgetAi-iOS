//
//  EnvelopesView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct EnvelopesView: View {
    @Environment(EnvelopeService.self) private var envelopeService
    @Environment(AccountService.self) private var accountService
    @Environment(TransactionService.self) private var transactionService

    @State private var showCreateCategory = false
    @State private var showCreateEnvelope = false
    @State private var createEnvelopeCategoryId: String?
    @State private var showDeleteCategory: EnvelopeCategoryResponse?
    @State private var editingEnvelopeId: String?
    @State private var editedAllocation = ""
    @State private var detailEnvelopeId: String?
    @FocusState private var allocationFieldFocused: Bool

    var body: some View {
        Group {
            if envelopeService.isLoading && envelopeService.envelopes.isEmpty {
                ProgressView()
            } else if envelopeService.categories.isEmpty {
                ContentUnavailableView {
                    Label("No Envelopes Yet", systemImage: "envelope.open.fill")
                } description: {
                    Text("Create categories and envelopes to start budgeting your money.")
                } actions: {
                    Button("Create Category", systemImage: "folder.badge.plus") {
                        showCreateCategory = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                envelopesList
            }
        }
        .navigationTitle("Envelopes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        createEnvelopeCategoryId = nil
                        showCreateEnvelope = true
                    } label: {
                        Label("New Envelope", systemImage: "envelope.badge.shield.half.filled.fill")
                    }

                    Button {
                        showCreateCategory = true
                    } label: {
                        Label("New Category", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateCategory) {
            CreateCategorySheet()
        }
        .sheet(isPresented: $showCreateEnvelope) {
            CreateEnvelopeSheet(preselectedCategoryId: createEnvelopeCategoryId)
        }
        .confirmationDialog(
            "Delete Category",
            isPresented: Binding(
                get: { showDeleteCategory != nil },
                set: { if !$0 { showDeleteCategory = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let category = showDeleteCategory {
                Button("Delete \"\(category.name)\"", role: .destructive) {
                    Task {
                        _ = await envelopeService.deleteCategory(category)
                    }
                }
            }
            Button("Cancel", role: .cancel) { showDeleteCategory = nil }
        } message: {
            Text("This will delete the category and ALL envelopes within it. This cannot be undone.")
        }
        .navigationDestination(item: $detailEnvelopeId) { envelopeId in
            EnvelopeDetailView(envelopeId: envelopeId)
        }
        .onChange(of: allocationFieldFocused) { _, focused in
            if !focused, editingEnvelopeId != nil {
                Task { await saveInlineAllocation() }
            }
        }
        .refreshable {
            await envelopeService.loadAll()
        }
        .task {
            if envelopeService.envelopes.isEmpty {
                await envelopeService.loadAll()
            }
        }
    }

    // MARK: - Envelopes List

    private var envelopesList: some View {
        List {
            // Month Navigator
            Section {
                monthNavigator
            }

            // Summary
            Section {
                VStack(spacing: 12) {
                    Text(envelopeService.totalRemaining.asCurrency())
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(envelopeService.totalRemaining >= 0 ? Color.primary : Color.red)

                    Text("remaining to spend")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if envelopeService.totalMonthlyAllocated > 0 {
                        ProgressView(value: overallProgress)
                            .tint(overallProgressTint)
                    }

                    HStack(spacing: AppDesign.paddingLg) {
                        summaryItem(
                            label: "Spent",
                            value: envelopeService.totalMonthlySpent.asCurrency()
                        )
                        summaryItem(
                            label: "Budgeted",
                            value: envelopeService.totalMonthlyAllocated.asCurrency()
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }

            // Error banner
            if let error = envelopeService.errorMessage {
                Section {
                    ErrorBannerView(message: error) {
                        await envelopeService.loadAll()
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Category Sections
            ForEach(envelopeService.sortedCategories) { category in
                categorySection(category)
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            KeyboardDoneToolbar {
                allocationFieldFocused = false
            }
        }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button {
                envelopeService.previousMonth()
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(envelopeService.viewedMonthString)
                .font(.headline)

            Spacer()

            Button {
                envelopeService.nextMonth()
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private func summaryItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Overall Progress

    private var overallProgress: Double {
        let allocated = envelopeService.totalMonthlyAllocated
        guard allocated > 0 else { return 0 }
        return min(
            NSDecimalNumber(decimal: envelopeService.totalMonthlySpent / allocated).doubleValue,
            1.0
        )
    }

    // MARK: - Inline Allocation

    private func saveInlineAllocation() async {
        guard let id = editingEnvelopeId,
              let envelope = envelopeService.envelopes.first(where: { $0.id == id }) else {
            editingEnvelopeId = nil
            return
        }
        let cleaned = editedAllocation
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        editingEnvelopeId = nil
        guard let amount = Decimal(string: cleaned), amount >= 0 else { return }
        _ = await envelopeService.setAllocation(for: envelope, amount: amount)
    }

    private var overallProgressTint: Color {
        if overallProgress > 1   { return .red }
        if overallProgress > 0.85 { return .orange }
        return .green
    }

    // MARK: - Category Section

    private func categorySection(_ category: EnvelopeCategoryResponse) -> some View {
        let categoryEnvelopes = envelopeService.envelopesByCategory[category.id ?? ""] ?? []

        return Section {
            if categoryEnvelopes.isEmpty {
                HStack {
                    Text("No envelopes yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !category.isCCPayment {
                        Button("Add") {
                            createEnvelopeCategoryId = category.id
                            showCreateEnvelope = true
                        }
                        .font(.subheadline)
                    }
                }
            } else {
                ForEach(categoryEnvelopes) { envelope in
                    EnvelopeCardView(
                        envelope: envelope,
                        monthlyAllocation: envelopeService.monthlyAllocation(for: envelope),
                        monthlySpent: envelopeService.monthlySpent(for: envelope),
                        remaining: envelope.isCCPayment
                            ? envelopeService.remaining(for: envelope, accounts: accountService.accounts, transactions: transactionService.transactions)
                            : envelopeService.remaining(for: envelope),
                        isEditing: editingEnvelopeId == envelope.id,
                        editedAllocation: $editedAllocation,
                        allocationFocused: $allocationFieldFocused,
                        cardBalance: envelope.isCCPayment
                            ? envelopeService.cardBalance(for: envelope, accounts: accountService.accounts)
                            : nil,
                        isUnderfunded: envelopeService.isUnderfunded(envelope, accounts: accountService.accounts, transactions: transactionService.transactions),
                        ccCoveragePercent: envelope.isCCPayment
                            ? envelopeService.ccCoveragePercent(for: envelope, accounts: accountService.accounts, transactions: transactionService.transactions)
                            : nil
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if editingEnvelopeId == envelope.id {
                            // Already editing — do nothing, let focus handle it
                        } else {
                            // Commit any pending edit first
                            if editingEnvelopeId != nil {
                                Task { await saveInlineAllocation() }
                            }
                            editedAllocation = "\(envelopeService.monthlyAllocation(for: envelope))"
                            editingEnvelopeId = envelope.id
                            allocationFieldFocused = true
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            detailEnvelopeId = envelope.id
                        } label: {
                            Label("Details", systemImage: "info.circle")
                        }
                        .tint(.accentColor)
                    }
                }
            }
        } header: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(category.name)

                    if category.isCCPayment {
                        Text("AUTO")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                    }

                    Spacer()

                    if !category.isCCPayment {
                        Button {
                            createEnvelopeCategoryId = category.id
                            showCreateEnvelope = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.subheadline)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())

                        Button {
                            showDeleteCategory = category
                        } label: {
                            Image(systemName: "trash")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                }

                // CC Payment category summary: Total Debt / Funded / Status
                if category.isCCPayment, let categoryId = category.id {
                    let totalDebt = envelopeService.ccCategoryTotalDebt(categoryId: categoryId, accounts: accountService.accounts)
                    let totalFunded = envelopeService.ccCategoryTotalFunded(categoryId: categoryId, accounts: accountService.accounts, transactions: transactionService.transactions)
                    let fullyFunded = totalFunded >= totalDebt

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Total Debt")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(totalDebt.asCurrency())
                                .font(.caption.weight(.semibold))
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Funded")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(totalFunded.asCurrency())
                                .font(.caption.weight(.semibold))
                        }

                        Spacer()

                        if fullyFunded {
                            Text("Fully Funded")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.green)
                        } else {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("Underfunded")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                Text((totalDebt - totalFunded).asCurrency())
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EnvelopesView()
            .environment(EnvelopeService())
            .environment(AccountService())
            .environment(TransactionService())
    }
}
