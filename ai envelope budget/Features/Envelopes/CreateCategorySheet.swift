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
            VStack(spacing: AppDesign.paddingLg) {
                // Header
                Image(systemName: "folder.fill.badge.plus")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, AppDesign.paddingLg)

                // Name Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Category Name")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    TextField("e.g., Housing, Food & Dining", text: $name)
                        .textFieldStyle(.plain)
                        .formFieldBackground()
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
                        .foregroundStyle(.tertiary)
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
                        Text("Create Category")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isValid || isSubmitting)
                .padding(.horizontal, AppDesign.paddingLg)

                Spacer()
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
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
