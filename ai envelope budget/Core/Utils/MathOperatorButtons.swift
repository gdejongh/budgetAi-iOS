import SwiftUI

/// A row of +, −, ×, ÷ buttons designed to sit in a keyboard toolbar.
/// Tapping a button appends the corresponding operator to the bound text.
struct MathOperatorButtons: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            operatorButton("+", operator: "+")
            operatorButton("−", operator: "-")
            operatorButton("×", operator: "*")
            operatorButton("÷", operator: "/")
            Spacer()
        }
    }

    private func operatorButton(_ label: String, operator op: String) -> some View {
        Button {
            text.append(op)
        } label: {
            Text(label)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .frame(width: 44, height: 40)
                .background(Color.accentCyan.opacity(0.15))
                .foregroundStyle(Color.accentCyan)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentCyan.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
