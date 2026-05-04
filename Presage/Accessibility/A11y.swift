import SwiftUI

/// Accessibility helpers and environment-driven modifiers.
enum A11y {
    /// Posts a VoiceOver announcement. Used when a prediction resolves
    /// or the Brier score changes, so VoiceOver users hear the outcome.
    static func announce(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }
}

// MARK: - Reduce Motion–aware animation

extension View {
    /// Applies `animation` unless the system has Reduce Motion enabled.
    func reducibleAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(ReducibleAnimationModifier(animation: animation, value: value))
    }
}

private struct ReducibleAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation?
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

// MARK: - Differentiate Without Color

extension View {
    /// When Differentiate Without Color is enabled, applies an additional
    /// shape/icon overlay so the meaning isn't carried by hue alone.
    func differentiateWithIcon(_ systemName: String, when condition: Bool) -> some View {
        modifier(DifferentiateModifier(systemName: systemName, condition: condition))
    }
}

private struct DifferentiateModifier: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate
    let systemName: String
    let condition: Bool

    func body(content: Content) -> some View {
        if condition && differentiate {
            HStack(spacing: 4) {
                Image(systemName: systemName).font(.caption)
                content
            }
        } else {
            content
        }
    }
}

// MARK: - Reduce Transparency–aware material

extension View {
    /// Falls back to an opaque background when Reduce Transparency is on.
    func reducibleMaterial(_ material: Material, fallback: Color) -> some View {
        modifier(ReducibleMaterialModifier(material: material, fallback: fallback))
    }
}

private struct ReducibleMaterialModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let material: Material
    let fallback: Color

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(fallback)
        } else {
            content.background(material)
        }
    }
}
