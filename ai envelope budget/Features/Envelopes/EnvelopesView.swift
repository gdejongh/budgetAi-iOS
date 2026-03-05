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
    @State private var collapsedCategoryIds: Set<String> = {
        let saved = UserDefaults.standard.stringArray(forKey: "collapsedCategoryIds") ?? []
        return Set(saved)
    }()

    // MARK: - Collapse Helpers

    private func isCategoryCollapsed(_ id: String) -> Bool {
        collapsedCategoryIds.contains(id)
    }

    private func toggleCategory(_ id: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if collapsedCategoryIds.contains(id) {
                collapsedCategoryIds.remove(id)
            } else {
                collapsedCategoryIds.insert(id)
            }
        }
        UserDefaults.standard.set(Array(collapsedCategoryIds), forKey: "collapsedCategoryIds")
    }

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

            // Unallocated Banner
            if !envelopeService.envelopes.isEmpty {
                Section {
                    unallocatedBanner
                }
                .staggeredFadeIn(index: 1, isVisible: hasAppeared)
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

            // Categories — single section, one rounded container
            Section {
                ForEach(envelopeService.sortedCategories) { category in
                    categoryRows(category)
                }
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

    // MARK: - Unallocated Banner

    private var unallocatedBanner: some View {
        let unallocated = envelopeService.unallocatedAmount(
            accounts: accountService.accounts,
            transactions: transactionService.transactions
        )
        let color: Color = unallocated > 0 ? .warning : unallocated < 0 ? .danger : .success

        return VStack(spacing: 8) {
            Text("Unallocated")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)

            Text(unallocated.asCurrency())
                .font(.appStatLarge)
                .foregroundStyle(color)

            if unallocated < 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.appCaption)
                        .foregroundStyle(Color.danger)
                    Text("You have allocated more than your available cash. Adjust your allocations.")
                        .font(.appCaption)
                        .foregroundStyle(Color.danger)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 4)
            } else if unallocated > 0 {
                Text("Assign this money to your envelopes")
                    .font(.appCaption)
                    .foregroundStyle(Color.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: - Category Rows

    @ViewBuilder
    private func categoryRows(_ category: EnvelopeCategoryResponse) -> some View {
        let categoryEnvelopes = envelopeService.envelopesByCategory[category.id ?? ""] ?? []
        let collapsed = isCategoryCollapsed(category.id ?? "")

        // Category header row (swipeable)
        categoryHeaderRow(category: category, collapsed: collapsed)

        // Only show envelope rows when expanded
        if !collapsed {
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
                .transition(.opacity.combined(with: .move(edge: .top)))
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Category Header Row

    private func categoryHeaderRow(category: EnvelopeCategoryResponse, collapsed: Bool) -> some View {
        HStack(spacing: 8) {
            // Collapse chevron
            Image(systemName: collapsed ? "chevron.forward" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 16)
                .animation(.easeInOut(duration: 0.2), value: collapsed)

            Text(category.name)
                .font(.appBody)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textPrimary)

            if category.isCCPayment {
                BadgeView(text: "AUTO", color: .warning)
            }

            Spacer()

            // Right-side stats — compact, inline like YNAB
            if category.isCCPayment, let categoryId = category.id {
                let totalDebt = envelopeService.ccCategoryTotalDebt(categoryId: categoryId, accounts: accountService.accounts)
                let totalFunded = envelopeService.ccCategoryTotalFunded(categoryId: categoryId, accounts: accountService.accounts, transactions: transactionService.transactions)
                let fullyFunded = totalFunded >= totalDebt

                VStack(alignment: .trailing, spacing: 1) {
                    Text("Funded")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                    Text(totalFunded.asCurrency())
                        .font(.appCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textSecondary)
                }

                VStack(alignment: .trailing, spacing: 1) {
                    Text(fullyFunded ? "Available" : "Underfunded")
                        .font(.system(size: 10))
                        .foregroundStyle(fullyFunded ? Color.textMuted : Color.danger)
                    Text(fullyFunded ? totalFunded.asCurrency() : (totalDebt - totalFunded).asCurrency())
                        .font(.appCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(fullyFunded ? Color.success : Color.danger)
                }
            } else if let categoryId = category.id {
                let allocated = envelopeService.categoryMonthlyAllocated(categoryId: categoryId)
                let remaining = envelopeService.categoryRemaining(categoryId: categoryId)

                VStack(alignment: .trailing, spacing: 1) {
                    Text("Assigned")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                    Text(allocated.asCurrency())
                        .font(.appCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textSecondary)
                }

                VStack(alignment: .trailing, spacing: 1) {
                    Text("Available")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                    Text(remaining.asCurrency())
                        .font(.appCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(remaining >= 0 ? Color.success : Color.danger)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleCategory(category.id ?? "")
        }
        .listRowBackground(Color.bgSurface)
        .swipeActions(edge: .trailing) {
            if !category.isCCPayment {
                Button(role: .destructive) {
                    showDeleteCategory = category
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    createEnvelopeCategoryId = category.id
                    showCreateEnvelope = true
                } label: {
                    Label("Add Envelope", systemImage: "plus")
                }
                .tint(.accentCyan)
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