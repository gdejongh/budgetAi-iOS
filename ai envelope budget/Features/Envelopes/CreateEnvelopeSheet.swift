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
            ZStack {
                Color.bgPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppDesign.paddingLg) {
                        // Header
                        Image(systemName: "envelope.badge.shield.half.filled.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(LinearGradient.brand)
                            .shadow(color: .accentCyan.opacity(0.3), radius: 16)
                            .padding(.top, AppDesign.paddingMd)

                        VStack(spacing: AppDesign.paddingMd) {
                            // Envelope Name
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Envelope Name")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textSecondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)

                                TextField("e.g., Rent, Groceries", text: $name)
                                    .textFieldStyle(.plain)
                                    .padding(AppDesign.paddingSm + 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                            .fill(Color.bgInput)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                                    .stroke(Color.borderSubtle, lineWidth: 1)
                                            )
                                    )
                                    .foregroundStyle(Color.textPrimary)
                                    .autocorrectionDisabled()
                            }

                            // Category Picker (if not preselected)
                            if preselectedCategoryId == nil {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Category")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.textSecondary)
                                        .textCase(.uppercase)
                                        .tracking(0.5)

                                    if availableCategories.isEmpty {
                                        HStack(spacing: 8) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundStyle(Color.warning)
                                                .font(.caption)
                                            Text("Create a category first before adding envelopes.")
                                                .font(.caption)
                                                .foregroundStyle(Color.textMuted)
                                        }
                                        .padding(AppDesign.paddingSm + 4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                                .fill(Color.bgInput)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                                        .stroke(Color.borderSubtle, lineWidth: 1)
                                                )
                                        )
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
                                        .padding(AppDesign.paddingSm)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                                .fill(Color.bgInput)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                                        .stroke(Color.borderSubtle, lineWidth: 1)
                                                )
                                        )
                                    }
                                }
                            }

                            // Monthly Allocation
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Budget for \(envelopeService.viewedMonthString)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textSecondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)

                                HStack {
                                    Text("$")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.textSecondary)

                                    TextField("0.00", text: $allocationText)
                                        .textFieldStyle(.plain)
                                        .keyboardType(.decimalPad)
                                        .foregroundStyle(Color.textPrimary)
                                        .font(.title3)
                                }
                                .padding(AppDesign.paddingSm + 4)
                                .background(
                                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                        .fill(Color.bgInput)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                                .stroke(Color.borderSubtle, lineWidth: 1)
                                        )
                                )
                            }
                        }
                        .padding(.horizontal, AppDesign.paddingLg)

                        // Info
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(Color.accentCyan)
                                .font(.caption)
                            Text("This sets the initial monthly budget. You can adjust it anytime.")
                                .font(.caption)
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
                                        .tint(.white)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                }
                                Text("Create Envelope")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                    .fill(isValid ? AnyShapeStyle(LinearGradient.brand) : AnyShapeStyle(Color.textMuted.opacity(0.3)))
                            )
                            .glowShadow()
                        }
                        .disabled(!isValid || isSubmitting)
                        .padding(.horizontal, AppDesign.paddingLg)
                        .padding(.top, AppDesign.paddingSm)
                        .padding(.bottom, AppDesign.paddingXl)
                    }
                }
            }
            .navigationTitle("New Envelope")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
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
