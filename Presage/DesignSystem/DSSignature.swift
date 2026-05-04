import SwiftUI

// MARK: - Spine motif (the icon's central vertical hairline)
// A subtle vertical line at center-X that anchors the layout.
// This is the visual signature of Pari — the line between
// "your model" (left) and "reality" (right).
struct PariSpine: View {
    var opacity: Double = 0.18

    var body: some View {
        Rectangle()
            .fill(DS.Palette.separator)
            .frame(width: 1)
            .opacity(opacity)
            .frame(maxHeight: .infinity)
    }
}

// MARK: - Aim/target glyph (from the icon)
// Used for: tab bar selector, accuracy indicator, resolution badge
struct PariAim: View {
    var size: CGFloat = 16
    var filled: Bool = false
    var tint: Color = DS.Palette.accent

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(tint, lineWidth: 1.2)
                .frame(width: size, height: size)
            Circle()
                .strokeBorder(tint, lineWidth: 1.2)
                .frame(width: size * 0.55, height: size * 0.55)
            Circle()
                .fill(filled ? tint : Color.clear)
                .frame(width: size * 0.22, height: size * 0.22)
        }
    }
}

// MARK: - Ring Gauge — the hero element
// A circular progress ring with split-color gradient and an
// inner number. Used for the Brier-derived "accuracy" display.
struct RingGauge: View {
    let progress: Double      // 0...1
    let lineWidth: CGFloat
    let diameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animated: CGFloat = 0

    init(progress: Double, diameter: CGFloat = 240, lineWidth: CGFloat = 14) {
        self.progress = max(0, min(1, progress))
        self.diameter = diameter
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(DS.Palette.surfaceTertiary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Foreground gradient ring
            Circle()
                .trim(from: 0, to: animated)
                .stroke(
                    AngularGradient(
                        colors: [
                            DS.Palette.accent,
                            DS.Palette.accent.opacity(0.85),
                            DS.Palette.accentSecondary,
                            DS.Palette.accentSecondary
                        ],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: DS.Palette.accent.opacity(0.35), radius: 16, x: 0, y: 0)
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            if reduceMotion {
                animated = CGFloat(progress)
            } else {
                withAnimation(.spring(response: 1.2, dampingFraction: 0.85)) {
                    animated = CGFloat(progress)
                }
            }
        }
        .onChange(of: progress) { _, new in
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) {
                animated = CGFloat(new)
            }
        }
    }
}

// MARK: - Two-tone numeric
// Renders a number with the LAST digit in coral — the icon's
// signature treatment ("65%" / "80%" — the % sign is coral)
struct TwoToneNumber: View {
    let number: String
    let suffix: String
    var size: CGFloat = 56
    var primaryColor: Color = DS.Palette.textPrimary
    var accentColor: Color = DS.Palette.accentSecondary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(number)
                .foregroundStyle(primaryColor)
            Text(suffix)
                .foregroundStyle(accentColor)
        }
        .font(.system(size: size, weight: .bold, design: .rounded))
        .monospacedDigit()
        .kerning(DS.Tracking.display)
    }
}

// MARK: - The Présage logo wordmark
// Wordmark + aim-circle accent dot. Used in onboarding / splash where
// horizontal space is unconstrained.
struct PariWordmark: View {
    var size: CGFloat = 28

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.18) {
            Text("Présage")
                .font(.system(size: size, weight: .semibold, design: .default))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.4)
            Circle()
                .fill(DS.Palette.accent)
                .frame(width: size * 0.22, height: size * 0.22)
                .offset(y: -size * 0.04)
        }
        .accessibilityLabel("Présage")
    }
}

// MARK: - Compact brand glyph
// Toolbar-safe brand mark — just the accent aim circle inside a thin
// outline ring. Replaces the full wordmark in tight toolbar slots
// where "Présage" would truncate. iOS 26's toolbar adds its own
// background pill, so the glyph here stays unbacked.
struct PariBrandMark: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(DS.Palette.textPrimary.opacity(0.85), lineWidth: max(1, size * 0.08))
            Circle()
                .fill(DS.Palette.accent)
                .frame(width: size * 0.42, height: size * 0.42)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Présage")
    }
}
