import SwiftUI

/// A row of +, −, ×, ÷ buttons designed to sit in a keyboard toolbar.
/// Tapping a button appends the corresponding operator to the bound text.
struct MathOperatorButtons: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
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
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .frame(width: 40, height: 36)
                .background(Color.accentCyan.opacity(0.15))
                .foregroundStyle(Color.accentCyan)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
