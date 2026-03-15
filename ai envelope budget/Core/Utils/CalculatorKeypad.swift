import SwiftUI
import Combine

/// A custom calculator-style keypad for entering allocation amounts.
///
/// Layout:
/// ```
///  [ 7 ] [ 8 ] [ 9 ] [ − ]
///  [ 4 ] [ 5 ] [ 6 ] [ + ]
///  [ 1 ] [ 2 ] [ 3 ] [ = ]
///  [ ✕ ] [ 0 ] [ ⌫ ] [done]
/// ```
struct CalculatorKeypad: View {
    @Binding var text: String
    var onDone: () -> Void
    var onCancel: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            LazyVGrid(columns: columns, spacing: 0) {
                // Row 1: 7 8 9 −
                digitButton("7")
                digitButton("8")
                digitButton("9")
                operatorButton("−", op: "-")

                // Row 2: 4 5 6 +
                digitButton("4")
                digitButton("5")
                digitButton("6")
                operatorButton("+", op: "+")

                // Row 3: 1 2 3 =
                digitButton("1")
                digitButton("2")
                digitButton("3")
                equalsButton()

                // Row 4: ✕ 0 ⌫ done
                cancelButton()
                digitButton("0")
                backspaceButton()
                doneButton()
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Buttons

    private func digitButton(_ digit: String) -> some View {
        Button {
            text.append(digit)
        } label: {
            Text(digit)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(.label).opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 64)
        }
        .buttonStyle(.plain)
    }

    private func operatorButton(_ label: String, op: String) -> some View {
        Button {
            text.append(op)
        } label: {
            Text(label)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.accentCyan)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
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
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.accentCyan)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
        }
        .buttonStyle(.plain)
    }

    private func backspaceButton() -> some View {
        Button {
            if !text.isEmpty { text.removeLast() }
        } label: {
            Image(systemName: "delete.backward")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.accentCyan)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
        }
        .buttonStyle(.plain)
    }

    private func cancelButton() -> some View {
        Button {
            onCancel()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 36, height: 36)
                .background(Color(.systemGray3))
                .clipShape(Circle())
                .frame(maxWidth: .infinity)
                .frame(height: 64)
        }
        .buttonStyle(.plain)
    }

    private func doneButton() -> some View {
        Button {
            onDone()
        } label: {
            Text("done")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.accentCyan)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.vertical, 8)
                .padding(.trailing, 4)
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

