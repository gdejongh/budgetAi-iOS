//
//  Animations.swift
//  ai envelope budget
//
//  Reusable animation definitions matching the Angular frontend's micro-interactions.
//

import SwiftUI

// MARK: - Spring Presets

extension Animation {
    /// Bouncy entrance spring
    static let springBounce = Animation.spring(response: 0.4, dampingFraction: 0.7)
    /// Smooth transition spring
    static let springSmooth = Animation.spring(response: 0.5, dampingFraction: 0.85)
    /// Quick micro-interaction spring
    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.8)
}

// MARK: - Staggered Fade-In

struct StaggeredFadeIn: ViewModifier {
    let index: Int
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8)
                    .delay(Double(index) * 0.05),
                value: isVisible
            )
    }
}

extension View {
    /// Stagger the entrance of items in a list
    func staggeredFadeIn(index: Int, isVisible: Bool) -> some View {
        modifier(StaggeredFadeIn(index: index, isVisible: isVisible))
    }
}

// MARK: - Glow Pulse

struct GlowPulse: ViewModifier {
    let color: Color
    @State private var isGlowing = false

    func body(content: Content) -> some View {
        content
            .shadow(
                color: color.opacity(isGlowing ? 0.25 : 0.08),
                radius: isGlowing ? 12 : 6,
                x: 0, y: 0
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isGlowing = true
                }
            }
    }
}

extension View {
    /// Pulsing glow for attention-drawing elements
    func glowPulse(color: Color) -> some View {
        modifier(GlowPulse(color: color))
    }
}

// MARK: - Animated Number

extension View {
    /// Animated number transition
    func animatedNumber() -> some View {
        contentTransition(.numericText())
    }
}

// MARK: - Transitions

extension AnyTransition {
    /// Slide up + fade for cards
    static var slideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }
}
