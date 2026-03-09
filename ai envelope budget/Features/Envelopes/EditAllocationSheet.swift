import SwiftUI

/// A compact sheet for editing an envelope's monthly allocation.
/// Shows a text field with a $ prefix and math operator buttons above the keyboard.
struct EditAllocationSheet: View {
    let title: String
    let subtitle: String
    @Binding var text: String
    var isSaving: Bool
    var onSave: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(subtitle)
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                HStack(spacing: 4) {
                    Text("$")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textSecondary)

                    TextField("0.00", text: $text)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                        .multilineTextAlignment(.leading)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                MathOperatorButtons(text: $text)
                            }
                        }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await onSave() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}
