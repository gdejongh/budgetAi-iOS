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

    @State private var showCreateCategory = false
    @State private var showCreateEnvelope = false
    @State private var createEnvelopeCategoryId: String?
    @State private var showDeleteCategory: EnvelopeCategoryResponse?

    var body: some View {
        ZStack {
            Color.bgPrimary
                .ignoresSafeArea()

            if envelopeService.isLoading && envelopeService.envelopes.isEmpty {
                loadingView
            } else if envelopeService.categories.isEmpty {
                emptyStateView
            } else {
                envelopesList
            }
        }
        .navigationTitle("Envelopes")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(LinearGradient.brand)
                        .font(.title3)
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
        .navigationDestination(for: String.self) { envelopeId in
            EnvelopeDetailView(envelopeId: envelopeId)
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
        ScrollView {
            VStack(spacing: AppDesign.paddingLg) {
                // Month Navigator
                monthNavigator

                // Summary Card
                summaryCard

                // Error banner
                if let error = envelopeService.errorMessage {
                    errorBanner(error)
                }

                // Category Sections
                ForEach(envelopeService.sortedCategories) { category in
                    categorySection(category)
                }
            }
            .padding(.horizontal, AppDesign.paddingLg)
            .padding(.vertical, AppDesign.paddingMd)
        }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button {
                envelopeService.previousMonth()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentCyan)
            }

            Spacer()

            Text(envelopeService.viewedMonthString)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Button {
                envelopeService.nextMonth()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentCyan)
            }
        }
        .padding(.horizontal, AppDesign.paddingSm)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 8) {
            Text("Monthly Budget")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)

            GradientText(
                formatCurrency(envelopeService.totalMonthlyAllocated),
                font: .system(size: 28, weight: .bold, design: .rounded)
            )

            HStack(spacing: AppDesign.paddingLg) {
                summaryItem(
                    label: "Envelopes",
                    value: "\(envelopeService.envelopeCount)",
                    color: .accentCyan
                )
                summaryItem(
                    label: "Categories",
                    value: "\(envelopeService.categoryCount)",
                    color: .accentViolet
                )
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(AppDesign.paddingMd)
        .glassCard()
    }

    private func summaryItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.textMuted)
        }
    }

    // MARK: - Category Section

    private func categorySection(_ category: EnvelopeCategoryResponse) -> some View {
        let categoryEnvelopes = envelopeService.envelopesByCategory[category.id ?? ""] ?? []

        return VStack(alignment: .leading, spacing: AppDesign.paddingSm) {
            // Category Header
            HStack(spacing: 8) {
                Image(systemName: category.isCCPayment ? "creditcard.fill" : "folder.fill")
                    .font(.subheadline)
                    .foregroundStyle(LinearGradient.brand)

                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                if category.isCCPayment {
                    Text("AUTO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.accentViolet)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentViolet.opacity(0.15)))
                }

                Spacer()

                Text("\(categoryEnvelopes.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.bgCardHover))

                if !category.isCCPayment {
                    // Add envelope to this category
                    Button {
                        createEnvelopeCategoryId = category.id
                        showCreateEnvelope = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color.accentCyan)
                    }

                    // Delete category
                    Button {
                        showDeleteCategory = category
                    } label: {
                        Image(systemName: "trash.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color.danger.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 4)

            // Envelope Cards
            if categoryEnvelopes.isEmpty {
                emptyCategoryRow(category)
            } else {
                ForEach(categoryEnvelopes) { envelope in
                    NavigationLink(value: envelope.id ?? "") {
                        EnvelopeCardView(
                            envelope: envelope,
                            monthlyAllocation: envelopeService.monthlyAllocation(for: envelope),
                            monthlySpent: envelopeService.monthlySpent(for: envelope),
                            remaining: envelopeService.remaining(for: envelope)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func emptyCategoryRow(_ category: EnvelopeCategoryResponse) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope.open")
                .font(.caption)
                .foregroundStyle(Color.textMuted)

            Text("No envelopes yet")
                .font(.caption)
                .foregroundStyle(Color.textMuted)

            Spacer()

            if !category.isCCPayment {
                Button {
                    createEnvelopeCategoryId = category.id
                    showCreateEnvelope = true
                } label: {
                    Text("+ Add")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentCyan)
                }
            }
        }
        .padding(AppDesign.paddingSm + 4)
        .glassCard()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 56))
                .foregroundStyle(LinearGradient.brand)
                .shadow(color: .accentCyan.opacity(0.3), radius: 16)

            VStack(spacing: 8) {
                Text("No Envelopes Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)

                Text("Create categories and envelopes to start budgeting your money.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 12) {
                Button {
                    showCreateCategory = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                        Text("Create Category")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 32)
                    .background(LinearGradient.brand)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd))
                    .glowShadow()
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.accentCyan)

            Text("Loading envelopes…")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.danger)

            Text(message)
                .font(.caption)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Button {
                Task { await envelopeService.loadAll() }
            } label: {
                Text("Retry")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentCyan)
            }
        }
        .padding(AppDesign.paddingSm)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                .fill(Color.danger.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                        .stroke(Color.danger.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

#Preview {
    NavigationStack {
        EnvelopesView()
            .environment(EnvelopeService())
            .environment(AccountService())
    }
}
