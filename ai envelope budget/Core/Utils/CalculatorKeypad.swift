import SwiftUI
import Combine

/// A custom calculator-style keypad for entering allocation amounts with built-in
/// arithmetic operators, inspired by YNAB's budget input.
///
/// Layout (standard calculator):
/// ```
///  [ 7 ] [ 8 ] [ 9 ]  [ ÷ ]
///  [ 4 ] [ 5 ] [ 6 ]  [ × ]
///  [ 1 ] [ 2 ] [ 3 ]  [ − ]
///  [ . ] [ 0 ] [ ⌫ ]  [ + ]
///  [ ✕ ]       [ = ]  [done]
/// ```
struct CalculatorKeypad: View {
    @Binding var text: String
    var onDone: () -> Void
    var onCancel: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            LazyVGrid(columns: columns, spacing: 8) {
                // Row 1: 7 8 9 ÷
                digitButton("7")
                digitButton("8")
                digitButton("9")
                operatorButton("÷", op: "/")

                // Row 2: 4 5 6 ×
                digitButton("4")
                digitButton("5")
                digitButton("6")
                operatorButton("×", op: "*")

                // Row 3: 1 2 3 −
                digitButton("1")
                digitButton("2")
                digitButton("3")
                operatorButton("−", op: "-")

                // Row 4: . 0 ⌫ +
                decimalButton()
                digitButton("0")
                backspaceButton()
                operatorButton("+", op: "+")

                // Row 5: ✕ (spacer) = done
                cancelButton()
                Color.clear.frame(height: 48) // spacer
                equalsButton()
                doneButton()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Buttons

    private func digitButton(_ digit: String) -> some View {
        Button {
            text.append(digit)
        } label: {
            Text(digit)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func decimalButton() -> some View {
        Button {
            // Allow decimal if the current number segment doesn't already have one
            let lastSegment = text.split(omittingEmptySubsequences: false,
                                         whereSeparator: { "+-*/".contains($0) }).last ?? ""
            if !lastSegment.contains(".") {
                text.append(".")
            }
        } label: {
            Text(".")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func operatorButton(_ label: String, op: String) -> some View {
        Button {
            text.append(op)
        } label: {
            Text(label)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(Color.accentCyan)
                .background(Color.accentCyan.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func equalsButton() -> some View {
        Button {
            if let result = evaluateMathExpression(text) {
                text = "\(result)"
            }
        } label: {
            Text("=")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(.white)
                .background(Color.accentCyan)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func backspaceButton() -> some View {
        Button {
            if !text.isEmpty {
                text.removeLast()
            }
        } label: {
            Image(systemName: "delete.backward")
                .font(.system(size: 20, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func cancelButton() -> some View {
        Button {
            onCancel()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(Color.danger)
                .background(Color.danger.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func doneButton() -> some View {
        Button {
            onDone()
        } label: {
            Text("done")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(.white)
                .background(Color.accentViolet)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Modifier

/// Attaches a `CalculatorKeypad` to the bottom of a view, shown/hidden by `isEditing`.
/// Automatically hides the calculator when the system keyboard appears (e.g. user taps a text field).
struct CalculatorKeypadInputModifier: ViewModifier {
    @Binding var text: String
    @Binding var isEditing: Bool

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                if isEditing {
                    CalculatorKeypad(
                        text: $text,
                        onDone: { isEditing = false },
                        onCancel: { isEditing = false }
                    )
                    .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isEditing)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                if isEditing {
                    isEditing = false
                }
            }
    }
}

extension View {
    /// Attach the custom calculator keypad to this view.
    func calculatorKeypadInput(text: Binding<String>, isEditing: Binding<Bool>) -> some View {
        modifier(CalculatorKeypadInputModifier(text: text, isEditing: isEditing))
    }
}
