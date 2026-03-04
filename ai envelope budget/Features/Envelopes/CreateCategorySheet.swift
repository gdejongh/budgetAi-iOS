//
//  CreateCategorySheet.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct CreateCategorySheet: View {
    @Environment(EnvelopeService.self) private var envelopeService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary
                    .ignoresSafeArea()

                VStack(spacing: AppDesign.paddingLg) {
                    // Header
                    Image(systemName: "folder.fill.badge.plus")
                        .font(.system(size: 44))
                        .foregroundStyle(LinearGradient.brand)
                        .shadow(color: .accentCyan.opacity(0.3), radius: 16)
                        .padding(.top, AppDesign.paddingLg)

                    // Name Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category Name")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        TextField("e.g., Housing, Food & Dining", text: $name)
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
                    .padding(.horizontal, AppDesign.paddingLg)

                    // Info
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.accentCyan)
                            .font(.caption)
                        Text("Categories group related envelopes together, like \"Bills\" or \"Savings\".")
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
                            Text("Create Category")
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

                    Spacer()
                }
            }
            .navigationTitle("New Category")
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func create() async {
        isSubmitting = true
        let success = await envelopeService.createCategory(
            name: name.trimmingCharacters(in: .whitespaces)
        )
        if success {
            dismiss()
        } else {
            errorMessage = envelopeService.errorMessage ?? "Failed to create category."
            showError = true
        }
        isSubmitting = false
    }
}
