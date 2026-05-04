import SwiftUI

/// The hero block — a ring gauge wrapped around the Brier-derived
/// "calibration accuracy" number, with the two-tone signature numeric
/// (digit primary + % coral) at center.
struct BrierScoreHero: View {
    let brierScore: Double?
    let totalResolved: Int
    let previousScore: Double?

    @Environment(\.colorScheme) private var scheme
    @State private var displayedAccuracy: Double = 0

    private var accuracy: Double {
        guard let b = brierScore else { return 0 }
        // Convert Brier (0=perfect, 0.25=random) → 0...100 accuracy
        return max(0, min(100, (1 - b * 4) * 100))
    }

    var body: some View {
        VStack(spacing: 24) {
            qualitativeState

            ZStack {
                RingGauge(progress: accuracy / 100, diameter: 240, lineWidth: 12)

                VStack(spacing: 4) {
                    if brierScore != nil {
                        TwoToneNumber(
                            number: "\(Int(displayedAccuracy.rounded()))",
                            suffix: "%",
                            size: 64
                        )

                        Text("calibration accuracy")
                            .font(DS.Typo.footnote)
                            .foregroundStyle(DS.Palette.textSecondary)
                    } else {
                        Text("—")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Palette.textTertiary)
                        Text("awaiting data")
                            .font(DS.Typo.footnote)
                            .foregroundStyle(DS.Palette.textTertiary)
                    }
                }
            }

            footer
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onAppear { animateIn() }
        .onChange(of: brierScore) { _, _ in animateIn() }
    }

    // MARK: - Subviews

    private var qualitativeState: some View {
        WhisperLabel(text: qualitativeText, color: qualitativeTint)
    }

    private var qualitativeTint: Color {
        guard let b = brierScore else { return DS.Palette.textTertiary }
        switch b {
        case ..<0.10: return DS.Palette.accent
        case ..<0.20: return DS.Palette.textSecondary
        default:      return DS.Palette.accentSecondary
        }
    }

    private var qualitativeText: String {
        guard let b = brierScore else { return "Awaiting Data" }
        switch b {
        case ..<0.05: return "Exceptionally Calibrated"
        case ..<0.10: return "Well Calibrated"
        case ..<0.15: return "Reasonably Calibrated"
        case ..<0.20: return "Slightly Overconfident"
        case ..<0.25: return "Overconfident"
        default:      return "Worse Than Random"
        }
    }

    private var footer: some View {
        HStack(spacing: 24) {
            footerStat(label: "Brier", value: brierScoreString, isCoral: false)

            Rectangle()
                .fill(DS.Palette.separator)
                .frame(width: 1, height: 28)

            footerStat(label: "Resolved", value: "\(totalResolved)", isCoral: true)

            if let delta = scoreDelta {
                Rectangle()
                    .fill(DS.Palette.separator)
                    .frame(width: 1, height: 28)

                deltaIndicator(delta)
            }
        }
    }

    private func footerStat(label: String, value: String, isCoral: Bool) -> some View {
        VStack(spacing: 4) {
            WhisperLabel(text: label)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(isCoral ? DS.Palette.accentSecondary : DS.Palette.textPrimary)
                .monospacedDigit()
        }
    }

    private var brierScoreString: String {
        guard let b = brierScore else { return "—" }
        return PariFormat.brier(b)
    }

    private var scoreDelta: Double? {
        guard let current = brierScore, let prev = previousScore else { return nil }
        let d = current - prev
        return abs(d) > 0.001 ? d : nil
    }

    private func deltaIndicator(_ delta: Double) -> some View {
        let improving = delta < 0
        return VStack(spacing: 4) {
            WhisperLabel(text: improving ? "Improving" : "Slipping")
            HStack(spacing: 2) {
                Image(systemName: improving ? "arrow.down.right" : "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                Text(PariFormat.brier(abs(delta)))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(improving ? DS.Palette.accent : DS.Palette.accentSecondary)
        }
    }

    private func animateIn() {
        withAnimation(.spring(response: 1.2, dampingFraction: 0.85)) {
            displayedAccuracy = accuracy
        }
    }

    private var accessibilityLabel: String {
        guard brierScore != nil else { return "Awaiting data — make and resolve predictions" }
        return "\(qualitativeText). Calibration accuracy \(Int(accuracy.rounded())) percent. Brier score \(brierScoreString) across \(totalResolved) resolved predictions."
    }
}
