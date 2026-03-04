//
//  SharedComponents.swift
//  ai envelope budget
//
//  Shared UI components and utilities used across the app.
//

import SwiftUI

// MARK: - Error Banner

/// Inline error banner with simple styling.
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
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.danger.opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}

// MARK: - Empty State View

/// Full-screen empty state with icon, heading, body text, and optional action button.
struct EmptyStateView: View {
    let icon: String
    let heading: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    init(icon: String, heading: String, body: String, actionLabel: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.heading = heading
        self.message = body
        self.actionLabel = actionLabel
        self.action = action
    }

    var body: some View {
        ContentUnavailableView {
            Label(heading, systemImage: icon)
                .foregroundStyle(Color.accentCyan)
        } description: {
            Text(message)
                .foregroundStyle(Color.textSecondary)
        } actions: {
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

// MARK: - Badge View

/// Reusable capsule badge with semantic color.
struct BadgeView: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 2) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
            }
            Text(text)
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.15)))
    }
}

// MARK: - Stat Card

/// Icon + label + value stat display matching Angular stat cards.
struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    var iconColor: Color = .accentCyan
    var valueColor: Color = .textPrimary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                        .fill(iconColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.appLabel)
                    .foregroundStyle(Color.textMuted)
                    .textCase(.uppercase)
                    .labelTracking()

                Text(value)
                    .font(.appNumber(.title3, weight: .bold))
                    .foregroundStyle(valueColor)
            }
        }
    }
}

// MARK: - Brand Progress Bar

/// Native iOS progress bar with semantic tint color.
struct BrandProgressBar: View {
    let value: Double
    var tint: Color = .accentCyan
    var height: CGFloat = 8

    var body: some View {
        ProgressView(value: min(max(value, 0), 1.0))
            .tint(tint)
            .animation(.easeOut(duration: 0.6), value: value)
    }
}

// MARK: - Shimmer Loading

/// Skeleton loading placeholder with sweeping gradient animation.
struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    var height: CGFloat = 16
    var cornerRadius: CGFloat = AppDesign.cornerRadiusSm

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.bgCardHover)
            .frame(height: height)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.bgCard.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.4)
                    .offset(x: geo.size.width * (phase - 0.2))
                }
                .clipped()
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

// MARK: - Loading Dots

/// Pulsing dot animation for AI loading states.
struct LoadingDots: View {
    @State private var activeDot = 0
    let color: Color

    init(color: Color = .accentViolet) {
        self.color = color
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .scaleEffect(activeDot == i ? 1.3 : 0.7)
                    .opacity(activeDot == i ? 1 : 0.4)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    activeDot = (activeDot + 1) % 3
                }
            }
        }
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

/// Themed form field background — simple and native.
struct FormFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
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

/// Cyan-filled button matching the brand accent.
struct PrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? .white : Color.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isEnabled ? AnyShapeStyle(Color.accentCyan) : AnyShapeStyle(Color(.tertiarySystemFill)))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Gradient Button Style

/// Cyan → violet gradient button for AI / premium actions.
struct GradientButtonStyle: ButtonStyle {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isEnabled ? AnyShapeStyle(LinearGradient.brand) : AnyShapeStyle(Color(.tertiarySystemFill)))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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
