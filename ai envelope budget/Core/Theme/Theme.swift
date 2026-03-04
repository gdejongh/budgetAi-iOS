//
//  Theme.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

// MARK: - Semantic Color Palette (System-Adaptive)

extension Color {
    // Backgrounds — adapt automatically to light/dark mode
    static let bgPrimary = Color(.systemBackground)
    static let bgSurface = Color(.secondarySystemBackground)
    static let bgCard = Color(.secondarySystemGroupedBackground)
    static let bgCardHover = Color(.quaternarySystemFill)
    static let bgInput = Color(.secondarySystemBackground)

    // Accents — use the app-wide tint + a secondary brand color
    static let accentCyan = Color.accentColor
    static let accentViolet = Color.indigo

    // Text — system label hierarchy, adapts to appearance & accessibility
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textMuted = Color(.tertiaryLabel)

    // Semantic — system colors that adapt to increased contrast
    static let success = Color.green
    static let warning = Color.yellow
    static let danger = Color.red

    // Borders — system separator adapts to all modes
    static let borderSubtle = Color(.separator)
    static let borderFocus = Color.accentColor
}

// MARK: - Gradients

extension LinearGradient {
    static let brand = LinearGradient(
        colors: [.accentCyan, .accentViolet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - View Modifiers

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.regularMaterial)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    /// Standard subtle shadow for card elevation
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Design Constants

enum AppDesign {
    static let cornerRadiusSm: CGFloat = 8
    static let cornerRadiusMd: CGFloat = 12
    static let cornerRadiusLg: CGFloat = 16
    static let cornerRadiusXl: CGFloat = 24

    static let paddingSm: CGFloat = 8
    static let paddingMd: CGFloat = 16
    static let paddingLg: CGFloat = 24
    static let paddingXl: CGFloat = 32
}
