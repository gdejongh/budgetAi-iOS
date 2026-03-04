//
//  SharedComponents.swift
//  ai envelope budget
//
//  Shared UI components and utilities used across the app.
//

import SwiftUI

// MARK: - Error Banner

/// Reusable inline error banner with retry action.
struct ErrorBannerView: View {
    let message: String
    var retryAction: (() async -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.danger)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            if let retryAction {
                Button {
                    Task { await retryAction() }
                } label: {
                    Text("Retry")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(AppDesign.paddingSm + 4)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                .fill(Color.danger.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                        .stroke(Color.danger.opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}

// MARK: - Currency Formatting

extension Decimal {
    /// Formats as USD currency string (e.g., "$1,234.56")
    func asCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "$0.00"
    }

    /// Formats as signed USD currency (e.g., "+$100.00" or "-$42.50")
    func asSignedCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+$"
        formatter.negativePrefix = "-$"
        return formatter.string(from: self as NSDecimalNumber) ?? "$0.00"
    }

    /// VoiceOver-friendly spoken currency (e.g., "forty two dollars and fifty cents")
    func asCurrencyAccessibilityLabel() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        let dollars = NSDecimalNumber(decimal: self).intValue
        let cents = NSDecimalNumber(decimal: (self - Decimal(dollars)) * 100).intValue
        let absDollars = abs(dollars)
        let absCents = abs(cents)
        let sign = self < 0 ? "negative " : ""
        if absCents == 0 {
            return "\(sign)\(absDollars) dollars"
        }
        return "\(sign)\(absDollars) dollars and \(absCents) cents"
    }
}

// MARK: - Keyboard Done Toolbar

/// A toolbar "Done" button for dismissing keyboards (especially decimal pad).
struct KeyboardDoneToolbar: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                action()
            }
            .fontWeight(.semibold)
        }
    }
}

// MARK: - Form Field Style

/// Native-looking form field background using system materials.
struct FormFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppDesign.paddingSm + 4)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

extension View {
    func formFieldBackground() -> some View {
        modifier(FormFieldBackground())
    }
}

// MARK: - Primary Button Style

/// Standard filled button matching iOS conventions.
struct PrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                    .fill(isEnabled ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.tertiaryLabel)))
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Date Formatting

extension String {
    /// Parses an ISO date string into a display-friendly format (e.g., "Mar 1, 2026")
    func asFormattedDate() -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none

        if let date = isoFormatter.date(from: self) {
            return displayFormatter.string(from: date)
        }
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: self) {
            return displayFormatter.string(from: date)
        }
        return self
    }
}
