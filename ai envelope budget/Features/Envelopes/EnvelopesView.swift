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
    @State private var hasAppeared = false

    var body: some View {
        Group {
            if envelopeService.isLoading && envelopeService.envelopes.isEmpty {
                ProgressView()
            } else if envelopeService.categories.isEmpty {
                EmptyStateView(
                    icon: "envelope.open.fill",
                    heading: "No Envelopes Yet",
                    body: "Create categories and envelopes to start budgeting your money.",
                    actionLabel: "Create Category"
                ) {
                    showCreateCategory = true
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
                        .font(.appStatLarge)
                        .foregroundStyle(envelopeService.totalRemaining >= 0 ? Color.textPrimary : Color.danger)

                    Text("remaining to spend")
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)

                    if envelopeService.totalMonthlyAllocated > 0 {
                        BrandProgressBar(value: overallProgress, tint: overallProgressTint)
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
            .staggeredFadeIn(index: 0, isVisible: hasAppeared)

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
        .brandListStyle()
        .onAppear { hasAppeared = true }
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
                    .foregroundStyle(Color.accentCyan)
            }

            Spacer()

            Text(envelopeService.viewedMonthString)
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Button {
                envelopeService.nextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.accentCyan)
            }
        }
    }

    private func summaryItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.appBody)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
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
        if overallProgress > 1   { return .danger }
        if overallProgress > 0.85 { return .warning }
        return .success
    }

    // MARK: - Category Section

    private func categorySection(_ category: EnvelopeCategoryResponse) -> some View {
        let categoryEnvelopes = envelopeService.envelopesByCategory[category.id ?? ""] ?? []

        return Section {
            if categoryEnvelopes.isEmpty {
                HStack {
                    Text("No envelopes yet")
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    if !category.isCCPayment {
                        Button("Add") {
                            createEnvelopeCategoryId = category.id
                            showCreateEnvelope = true
                        }
                        .font(.appCaption)
                        .foregroundStyle(Color.accentCyan)
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
                        .tint(.accentCyan)
                    }
                }
            }
        } header: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(category.name)
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)

                    if category.isCCPayment {
                        BadgeView(text: "AUTO", color: .warning)
                    }

                    Spacer()

                    if !category.isCCPayment {
                        Button {
                            createEnvelopeCategoryId = category.id
                            showCreateEnvelope = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.appCaption)
                                .foregroundStyle(Color.accentCyan)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())

                        Button {
                            showDeleteCategory = category
                        } label: {
                            Image(systemName: "trash")
                                .font(.appCaption)
                                .foregroundStyle(Color.danger)
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
                                .font(.appCaption)
                                .foregroundStyle(Color.textMuted)
                            Text(totalDebt.asCurrency())
                                .font(.appCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Funded")
                                .font(.appCaption)
                                .foregroundStyle(Color.textMuted)
                            Text(totalFunded.asCurrency())
                                .font(.appCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        if fullyFunded {
                            BadgeView(text: "Fully Funded", color: .success)
                        } else {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("Underfunded")
                                    .font(.appCaption)
                                    .foregroundStyle(Color.danger)
                                Text((totalDebt - totalFunded).asCurrency())
                                    .font(.appCaption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.danger)
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
