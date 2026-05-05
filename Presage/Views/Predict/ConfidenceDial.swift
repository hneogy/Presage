import SwiftUI

struct ConfidenceDial: View {
    @Binding var confidencePercent: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn
    @Environment(\.colorScheme) private var scheme
    @State private var lastSnapped: Int = 50
    @State private var lastAnnouncedLabel: String = ""
    @State private var trackWidth: CGFloat = 0

    private let trackHeight: CGFloat = 8
    private let thumbSize: CGFloat = 28

    private var normalizedValue: Double {
        Double(confidencePercent - 50) / 49.0
    }

    var body: some View {
        VStack(spacing: 28) {
            // Center label — number + uppercase verbal label
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(confidencePercent)")
                        .foregroundStyle(DS.Palette.textPrimary)
                    Text("%")
                        .foregroundStyle(DS.Palette.accentSecondary)
                }
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

                Text(ConfidenceLevel.verbalLabel(for: confidencePercent).uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(verbalLabelColor)
                    .kerning(2.0)
                    .reducibleAnimation(DS.Motion.stateAnimation, value: confidencePercent)
            }

            // Linear slider
            linearSlider

            // Min / Max anchor labels (50 ─── 99)
            HStack {
                anchorLabel("50", subtitle: "COIN FLIP")
                Spacer()
                anchorLabel("99", subtitle: "CERTAIN", trailing: true)
            }

            // Quick-pick chips
            quickPicks
        }
    }

    // MARK: - Linear slider

    private var linearSlider: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fillWidth = width * CGFloat(normalizedValue)

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(trackColor)
                    .frame(height: trackHeight)

                // Tick marks (subtle, on the track). Rasterised so the
                // 50 rectangles compose to a single Metal layer instead of
                // 50 separate SwiftUI redraws on every drag tick.
                HStack(spacing: 0) {
                    ForEach(ConfidenceLevel.allSteps, id: \.self) { step in
                        let isMajor = [50, 75, 99].contains(step)
                        let isPast = step <= confidencePercent
                        Rectangle()
                            .fill(isPast ? Color.white.opacity(isMajor ? 0.85 : 0.5)
                                         : DS.Palette.textTertiary.opacity(isMajor ? 0.55 : 0.3))
                            .frame(width: isMajor ? 2 : 1, height: isMajor ? 12 : 6)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, thumbSize / 2)
                .drawingGroup()

                // Filled gradient
                Capsule()
                    .fill(confidenceGradient)
                    .frame(width: max(thumbSize, fillWidth), height: trackHeight)
                    .shadow(color: thumbAccentColor.opacity(0.45), radius: 8, x: 0, y: 0)

                // Thumb
                thumb
                    .offset(x: max(0, min(width - thumbSize, fillWidth - thumbSize / 2)))
            }
            .contentShape(Rectangle().inset(by: -16))
            .gesture(dragGesture(in: width))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Confidence")
            .accessibilityValue("\(confidencePercent) percent — \(ConfidenceLevel.verbalLabel(for: confidencePercent))")
            .accessibilityAdjustableAction { direction in
                guard let idx = ConfidenceLevel.allSteps.firstIndex(of: confidencePercent) else { return }
                switch direction {
                case .increment where idx < ConfidenceLevel.allSteps.count - 1:
                    confidencePercent = ConfidenceLevel.allSteps[idx + 1]
                    HapticEngine.shared.confidenceTick(at: confidencePercent)
                case .decrement where idx > 0:
                    confidencePercent = ConfidenceLevel.allSteps[idx - 1]
                    HapticEngine.shared.confidenceTick(at: confidencePercent)
                default: break
                }
            }
            .onAppear { trackWidth = width }
            .onChange(of: width) { _, new in trackWidth = new }
        }
        .frame(height: thumbSize + 8)
    }

    private var trackColor: Color {
        DS.Palette.surfaceTertiary
    }

    private var confidenceGradient: LinearGradient {
        LinearGradient(
            colors: [
                DS.Palette.accent.opacity(0.85),
                DS.Palette.accent,
                DS.Palette.accentSecondary
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Thumb (the aim glyph from the icon)

    private var thumb: some View {
        ZStack {
            Circle()
                .fill(thumbAccentColor.opacity(0.35))
                .frame(width: thumbSize + 16, height: thumbSize + 16)
                .blur(radius: 8)

            Circle()
                .fill(scheme == .dark ? DS.Palette.darkSurfacePrimary : Color.white)
                .frame(width: thumbSize, height: thumbSize)
                .overlay(
                    Circle().strokeBorder(thumbAccentColor, lineWidth: 2.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

            Circle()
                .strokeBorder(thumbAccentColor.opacity(0.5), lineWidth: 1)
                .frame(width: thumbSize * 0.55, height: thumbSize * 0.55)

            Circle()
                .fill(thumbAccentColor)
                .frame(width: 5, height: 5)
        }
    }

    private var thumbAccentColor: Color {
        if confidencePercent >= 90 { return DS.Palette.accentSecondary }
        if confidencePercent >= 70 { return DS.Palette.accent }
        return DS.Palette.accent.opacity(0.85)
    }

    // MARK: - Anchor labels

    private func anchorLabel(_ value: String, subtitle: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 3) {
            HStack(spacing: 1) {
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Palette.textSecondary)
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.Palette.textTertiary)
            }
            Text(subtitle)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(DS.Palette.textTertiary)
                .kerning(1.4)
        }
    }

    private var verbalLabelColor: Color {
        if confidencePercent >= 95 { return DS.Palette.accentSecondary }
        if confidencePercent >= 80 { return DS.Palette.accent }
        return DS.Palette.textSecondary
    }

    // MARK: - Drag

    private func dragGesture(in width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let usable = max(1, width - thumbSize)
                let x = max(0, min(usable, value.location.x - thumbSize / 2))
                let fraction = Double(x / usable)
                let raw = 50 + Int((fraction * 49).rounded())
                let snapped = ConfidenceLevel.snap(raw)

                if reduceMotion {
                    confidencePercent = snapped
                } else {
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.82)) {
                        confidencePercent = snapped
                    }
                }

                if snapped != lastSnapped {
                    HapticEngine.shared.confidenceTick(at: snapped)
                    lastSnapped = snapped

                    if voiceOverOn {
                        let label = ConfidenceLevel.verbalLabel(for: snapped)
                        if label != lastAnnouncedLabel {
                            A11y.announce("\(snapped) percent — \(label)")
                            lastAnnouncedLabel = label
                        }
                    }
                }
            }
    }

    // MARK: - Quick Picks

    private var quickPicks: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach([55, 65, 75, 85, 90, 95], id: \.self) { value in
                    QuickPickChip(
                        value: value,
                        isSelected: confidencePercent == value
                    ) {
                        if reduceMotion {
                            confidencePercent = value
                        } else {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                confidencePercent = value
                            }
                        }
                        HapticEngine.shared.confidenceTick(at: value)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Quick pick chip

private struct QuickPickChip: View {
    let value: Int
    let isSelected: Bool
    let action: () -> Void

    private var tint: Color {
        if value >= 90 { return DS.Palette.accentSecondary }
        return DS.Palette.accent
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.8)
            }
            .foregroundStyle(isSelected ? DS.Palette.darkSurfacePrimary : DS.Palette.textSecondary)
            .frame(width: 56, height: 36)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(DS.Palette.surfaceTertiary))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : DS.Palette.separator, lineWidth: 0.5)
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.78), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set confidence to \(value) percent")
    }
}

// MARK: - Arc Shape (kept for any other arc usage)

struct ArcShape: Shape {
    let center: CGPoint
    let radius: CGFloat
    var endFraction: Double = 1.0

    var animatableData: Double {
        get { endFraction }
        set { endFraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(180 - 180 * endFraction),
            clockwise: true
        )
        return path
    }
}
