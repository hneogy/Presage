import SwiftUI

extension DS {
    enum Atmosphere {
        /// Home — teal bloom from bottom-center (the gauge lives there)
        static func home(_ scheme: ColorScheme) -> some View {
            AtmosphereBackground(
                tint: scheme == .dark ? Color(hex: 0x0F2A2A) : Color(hex: 0xE8F2F0),
                base: scheme == .dark ? Color(hex: 0x070D12) : Color(hex: 0xF6F4F0),
                position: UnitPoint(x: 0.5, y: 0.65),
                radius: 600
            )
        }

        /// Predict — coral whisper from upper-right
        static func predict(_ scheme: ColorScheme) -> some View {
            AtmosphereBackground(
                tint: scheme == .dark ? Color(hex: 0x2A1410) : Color(hex: 0xF6EDE6),
                base: scheme == .dark ? Color(hex: 0x070D12) : Color(hex: 0xF6F4F0),
                position: UnitPoint(x: 0.85, y: 0.15),
                radius: 500
            )
        }

        /// Insights — teal bloom from upper-left, balancing Home's bottom bloom.
        /// Pre-fix the tint was 0x102028 — only ~10 RGB units brighter than the
        /// 0x070D12 base, which read as flat black on most displays.
        static func insights(_ scheme: ColorScheme) -> some View {
            AtmosphereBackground(
                tint: scheme == .dark ? Color(hex: 0x143838) : Color(hex: 0xE8F2F0),
                base: scheme == .dark ? Color(hex: 0x070D12) : Color(hex: 0xF6F4F0),
                position: UnitPoint(x: 0.15, y: 0.2),
                radius: 620
            )
        }

        /// More — coral whisper from bottom-left, mirror of Predict's upper-right.
        /// Gives the tools/settings tab its own warmth while staying in the
        /// teal/coral palette family.
        static func more(_ scheme: ColorScheme) -> some View {
            AtmosphereBackground(
                tint: scheme == .dark ? Color(hex: 0x2A1812) : Color(hex: 0xF6EDE6),
                base: scheme == .dark ? Color(hex: 0x070D12) : Color(hex: 0xF6F4F0),
                position: UnitPoint(x: 0.15, y: 0.85),
                radius: 560
            )
        }
    }
}

struct AtmosphereBackground: View {
    let tint: Color
    let base: Color
    let position: UnitPoint
    var radius: CGFloat = 500

    var body: some View {
        ZStack {
            base
            RadialGradient(
                colors: [tint, tint.opacity(0)],
                center: position,
                startRadius: 0,
                endRadius: radius
            )
            .blendMode(.plusLighter)
            .opacity(0.7)
        }
        .ignoresSafeArea()
    }
}

/// Refined card surface — for the new dark navy palette.
struct PariSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(surfaceFill)

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [topEdge, .clear],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.4)
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: shadowColor, radius: 18, x: 0, y: 8)
            }
    }

    private var surfaceFill: LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [Color(hex: 0x142028), Color(hex: 0x0E1820)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [.white, Color(hex: 0xFAF8F2)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var topEdge: Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.9)
    }

    private var shadowColor: Color {
        scheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.05)
    }
}

extension View {
    func pariSurface() -> some View {
        modifier(PariSurface())
    }
}
