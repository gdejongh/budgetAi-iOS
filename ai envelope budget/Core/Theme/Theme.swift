//
//  Theme.swift
//  ai envelope budget
//
//  Design system matching the Angular frontend aesthetic.
//  Dark mode: deep navy backgrounds with cyan/violet neon accents.
//  Light mode: cool blue-gray with the same accent palette.
//

import SwiftUI

// MARK: - Adaptive Color Helper

private extension UIColor {
    static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }
}

// MARK: - Color Palette

extension Color {
    // MARK: Backgrounds

    /// App background — deep navy (dark) / cool blue-gray (light)
    static let bgPrimary = Color(UIColor.adaptive(
        light: UIColor(red: 0.941, green: 0.949, blue: 0.965, alpha: 1),  // #F0F2F7
        dark:  UIColor(red: 0.043, green: 0.055, blue: 0.078, alpha: 1)   // #0B0E14
    ))

    /// Surface layers — nav bars, tab bars, panels
    static let bgSurface = Color(UIColor.adaptive(
        light: UIColor(red: 0.898, green: 0.910, blue: 0.937, alpha: 1),  // #E5E8EF
        dark:  UIColor(red: 0.071, green: 0.086, blue: 0.125, alpha: 1)   // #121620
    ))

    /// Card backgrounds
    static let bgCard = Color(UIColor.adaptive(
        light: .white,                                                      // #FFFFFF
        dark:  UIColor(red: 0.094, green: 0.114, blue: 0.165, alpha: 1)   // #181D2A
    ))

    /// Hover / pressed card state
    static let bgCardHover = Color(UIColor.adaptive(
        light: UIColor(red: 0.941, green: 0.949, blue: 0.965, alpha: 1),  // #F0F2F7
        dark:  UIColor(red: 0.118, green: 0.145, blue: 0.212, alpha: 1)   // #1E2536
    ))

    /// Form input backgrounds
    static let bgInput = Color(UIColor.adaptive(
        light: UIColor(red: 0.910, green: 0.922, blue: 0.949, alpha: 1),  // #E8EBF2
        dark:  UIColor(red: 0.075, green: 0.094, blue: 0.145, alpha: 1)   // #131825
    ))

    // MARK: Accents

    /// Primary brand accent — cyan (from asset catalog AccentColor)
    static let accentCyan = Color.accentColor

    /// Secondary brand accent — indigo/violet
    static let accentViolet = Color(UIColor.adaptive(
        light: UIColor(red: 0.388, green: 0.400, blue: 0.945, alpha: 1),  // #6366F1
        dark:  UIColor(red: 0.506, green: 0.549, blue: 0.973, alpha: 1)   // #818CF8
    ))

    /// Credit card / tertiary accent — orange
    static let accentOrange = Color(UIColor.adaptive(
        light: UIColor(red: 0.920, green: 0.533, blue: 0.133, alpha: 1),  // #EB8822
        dark:  UIColor(red: 0.984, green: 0.573, blue: 0.235, alpha: 1)   // #FB923C
    ))

    // MARK: Text

    /// Primary text
    static let textPrimary = Color(UIColor.adaptive(
        light: UIColor(red: 0.102, green: 0.114, blue: 0.141, alpha: 1),  // #1A1D24
        dark:  UIColor(red: 0.910, green: 0.918, blue: 0.929, alpha: 1)   // #E8EAED
    ))

    /// Secondary text — subtitles, descriptions
    static let textSecondary = Color(UIColor.adaptive(
        light: UIColor(red: 0.373, green: 0.400, blue: 0.447, alpha: 1),  // #5F6672
        dark:  UIColor(red: 0.604, green: 0.627, blue: 0.671, alpha: 1)   // #9AA0AB
    ))

    /// Muted text — timestamps, hints
    static let textMuted = Color(UIColor.adaptive(
        light: UIColor(red: 0.604, green: 0.627, blue: 0.671, alpha: 1),  // #9AA0AB
        dark:  UIColor(red: 0.373, green: 0.400, blue: 0.447, alpha: 1)   // #5F6672
    ))

    // MARK: Semantic

    /// Positive — income, success states
    static let success = Color(UIColor.adaptive(
        light: UIColor(red: 0.020, green: 0.588, blue: 0.412, alpha: 1),  // #059669
        dark:  UIColor(red: 0.204, green: 0.827, blue: 0.600, alpha: 1)   // #34D399
    ))

    /// Caution — warnings, unallocated funds
    static let warning = Color(UIColor.adaptive(
        light: UIColor(red: 0.851, green: 0.467, blue: 0.024, alpha: 1),  // #D97706
        dark:  UIColor(red: 0.984, green: 0.749, blue: 0.141, alpha: 1)   // #FBBF24
    ))

    /// Negative — expenses, errors, overspent
    static let danger = Color(UIColor.adaptive(
        light: UIColor(red: 0.863, green: 0.149, blue: 0.149, alpha: 1),  // #DC2626
        dark:  UIColor(red: 0.973, green: 0.443, blue: 0.443, alpha: 1)   // #F87171
    ))

    // MARK: Borders

    /// Very subtle dividers
    static let borderSubtle = Color(UIColor.adaptive(
        light: UIColor(red: 0, green: 0, blue: 0, alpha: 0.06),
        dark:  UIColor(red: 1, green: 1, blue: 1, alpha: 0.06)
    ))

    /// Default borders
    static let borderDefault = Color(UIColor.adaptive(
        light: UIColor(red: 0, green: 0, blue: 0, alpha: 0.10),
        dark:  UIColor(red: 1, green: 1, blue: 1, alpha: 0.10)
    ))

    /// Focus ring — matches accent
    static let borderFocus = Color.accentColor
}

// MARK: - Gradients

extension LinearGradient {
    /// Brand gradient: cyan → violet (diagonal)
    static let brand = LinearGradient(
        colors: [Color(red: 0.133, green: 0.827, blue: 0.933),
                 Color(red: 0.506, green: 0.549, blue: 0.973)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Brand gradient: cyan → violet (horizontal) — card top borders
    static let brandHorizontal = LinearGradient(
        colors: [Color(red: 0.133, green: 0.827, blue: 0.933),
                 Color(red: 0.506, green: 0.549, blue: 0.973)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Typography

extension Font {
    /// Large page title
    static let appLargeTitle = Font.system(.largeTitle, weight: .bold)
    /// Section title
    static let appTitle = Font.system(.title2, weight: .bold)
    /// Card/row heading
    static let appHeadline = Font.system(.headline, weight: .semibold)
    /// Body text
    static let appBody = Font.system(.body, weight: .medium)
    /// Descriptions and subtitles
    static let appSubheadline = Font.system(.subheadline)
    /// Small metadata
    static let appCaption = Font.system(.caption, weight: .medium)
    /// Tiny labels (uppercase use)
    static let appLabel = Font.system(.caption2, weight: .semibold)
    /// Large stat value (net worth, hero balances)
    static let appStatLarge = Font.system(size: 32, weight: .bold, design: .rounded)
    /// Medium stat value
    static let appStatMedium = Font.system(size: 24, weight: .bold, design: .rounded)
    /// Inline monetary value
    static func appNumber(_ style: Font.TextStyle = .body, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

extension View {
    /// Tight letter spacing for headings
    func headingTracking() -> some View {
        tracking(-0.3)
    }

    /// Wide letter spacing for uppercase labels
    func labelTracking() -> some View {
        tracking(0.8)
    }

    /// Apply brand gradient as foreground
    func gradientForeground() -> some View {
        foregroundStyle(LinearGradient.brand)
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

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = AppDesign.cornerRadiusLg
    var showTopBorder: Bool = false

    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = AppDesign.cornerRadiusLg, showTopBorder: Bool = false) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, showTopBorder: showTopBorder))
    }
}

// MARK: - Neon Border Modifier

struct NeonBorder: ViewModifier {
    let color: Color
    var cornerRadius: CGFloat = AppDesign.cornerRadiusLg

    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func neonBorder(color: Color, cornerRadius: CGFloat = AppDesign.cornerRadiusLg) -> some View {
        modifier(NeonBorder(color: color, cornerRadius: cornerRadius))
    }
}

// MARK: - Shadow Extensions

extension View {
    func shadowSm() -> some View {
        self
    }

    func shadowMd() -> some View {
        self
    }

    func shadowLg() -> some View {
        self
    }

    func shadowGlow(color: Color = .accentCyan) -> some View {
        self
    }

    /// Legacy card shadow
    func cardShadow() -> some View {
        self
    }
}

// MARK: - Brand List Styling

extension View {
    /// Themed full-width plain list — edge-to-edge sections
    func brandListStyle() -> some View {
        self
            .listStyle(.plain)
    }

    /// Themed section row background for lists
    func brandRowBackground() -> some View {
        self.listRowBackground(Color.bgCard)
    }
}

// MARK: - Brand Section Header

struct BrandSectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionIcon: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.appLabel)
                .foregroundStyle(Color.textMuted)
                .textCase(.uppercase)
                .labelTracking()

            Spacer()

            if let action, let actionIcon {
                Button(action: action) {
                    Image(systemName: actionIcon)
                        .font(.subheadline)
                        .foregroundStyle(Color.accentCyan)
                }
            }
        }
    }
}
