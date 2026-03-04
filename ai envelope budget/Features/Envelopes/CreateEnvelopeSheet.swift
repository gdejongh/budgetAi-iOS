//
//  CreateEnvelopeSheet.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct CreateEnvelopeSheet: View {
    @Environment(EnvelopeService.self) private var envelopeService
    @Environment(\.dismiss) private var dismiss

    /// Pre-selected category (if coming from a specific category section)
    let preselectedCategoryId: String?

    @State private var name = ""
    @State private var allocationText = ""
    @State private var selectedCategoryId: String?
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isAllocationFocused: Bool

    init(preselectedCategoryId: String? = nil) {
        self.preselectedCategoryId = preselectedCategoryId
    }

    private var parsedAllocation: Decimal? {
        let cleaned = allocationText
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { return Decimal.zero }
        return Decimal(string: cleaned)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && parsedAllocation != nil
            && effectiveCategoryId != nil
    }

    private var effectiveCategoryId: String? {
        selectedCategoryId ?? preselectedCategoryId
    }

    /// Only standard categories for creating envelopes
    private var availableCategories: [EnvelopeCategoryResponse] {
        envelopeService.standardCategories
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppDesign.paddingLg) {
                    // Header
                    Image(systemName: "envelope.badge.shield.half.filled.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentCyan)
                        .padding(.top, AppDesign.paddingMd)

                    VStack(spacing: AppDesign.paddingMd) {
                        // Envelope Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Envelope Name")
                                .font(.appCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            TextField("e.g., Rent, Groceries", text: $name)
                                .textFieldStyle(.plain)
                                .formFieldBackground()
                                .autocorrectionDisabled()
                        }

                        // Category Picker (if not preselected)
                        if preselectedCategoryId == nil {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Category")
                                    .font(.appCaption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textSecondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)

                                if availableCategories.isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(Color.warning)
                                            .font(.appCaption)
                                        Text("Create a category first before adding envelopes.")
                                            .font(.appCaption)
                                            .foregroundStyle(Color.textMuted)
                                    }
                                    .formFieldBackground()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    Picker("Category", selection: $selectedCategoryId) {
                                        Text("Select a category")
                                            .tag(nil as String?)
                                        ForEach(availableCategories) { category in
                                            Text(category.name).tag(category.id as String?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.accentCyan)
                                    .formFieldBackground()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        // Monthly Allocation
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Budget for \(envelopeService.viewedMonthString)")
                                .font(.appCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            HStack {
                                Text("$")
                                    .font(.appTitle)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textSecondary)

                                TextField("0.00", text: $allocationText)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.decimalPad)
                                    .focused($isAllocationFocused)
                                    .font(.appTitle)
                            }
                            .formFieldBackground()
                        }
                    }
                    .padding(.horizontal, AppDesign.paddingLg)

                    // Info
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.accentCyan)
                            .font(.appCaption)
                        Text("This sets the initial monthly budget. You can adjust it anytime.")
                            .font(.appCaption)
                            .foregroundStyle(Color.textMuted)
                    }
                    .padding(.horizontal, AppDesign.paddingLg)

                    // Create Button
                    Button {
                        Task { await create() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Create Envelope")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .controlSize(.large)
                    .disabled(!isValid || isSubmitting)
                    .padding(.horizontal, AppDesign.paddingLg)
                    .padding(.top, AppDesign.paddingSm)
                    .padding(.bottom, AppDesign.paddingXl)
                }
            }
            .navigationTitle("New Envelope")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                KeyboardDoneToolbar {
                    isAllocationFocused = false
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func create() async {
        guard let categoryId = effectiveCategoryId,
              let allocation = parsedAllocation else { return }

        isSubmitting = true
        let success = await envelopeService.createEnvelope(
            name: name.trimmingCharacters(in: .whitespaces),
            categoryId: categoryId,
            initialAllocation: allocation
        )
        if success {
            dismiss()
        } else {
            errorMessage = envelopeService.errorMessage ?? "Failed to create envelope."
            showError = true
        }
        isSubmitting = false
    }
}
