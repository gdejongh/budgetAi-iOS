//
//  Theme.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

// MARK: - Color Palette

extension Color {
    // Backgrounds
    static let bgPrimary = Color(hex: "0b0e14")
    static let bgSurface = Color(hex: "121620")
    static let bgCard = Color(hex: "181d2a")
    static let bgCardHover = Color(hex: "1e2536")
    static let bgInput = Color(hex: "131825")

    // Accents
    static let accentCyan = Color(hex: "22d3ee")
    static let accentViolet = Color(hex: "818cf8")

    // Text
    static let textPrimary = Color(hex: "e8eaed")
    static let textSecondary = Color(hex: "9aa0ab")
    static let textMuted = Color(hex: "5f6672")

    // Semantic
    static let success = Color(hex: "34d399")
    static let warning = Color(hex: "fbbf24")
    static let danger = Color(hex: "f87171")

    // Borders
    static let borderSubtle = Color.white.opacity(0.06)
    static let borderFocus = Color(hex: "22d3ee")
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
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
                    .fill(Color.bgCard.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.borderSubtle, lineWidth: 1)
                    )
            )
    }
}

struct GlowShadow: ViewModifier {
    var color: Color = .accentCyan
    var radius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    func glowShadow(color: Color = .accentCyan, radius: CGFloat = 12) -> some View {
        modifier(GlowShadow(color: color, radius: radius))
    }
}

// MARK: - Gradient Text

struct GradientText: View {
    let text: String
    let font: Font

    init(_ text: String, font: Font = .largeTitle.bold()) {
        self.text = text
        self.font = font
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(LinearGradient.brand)
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
