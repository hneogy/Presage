import SwiftUI

/// The "Anti-feature" pitch — the brand differentiator for users who are
/// fed up with gamified self-care apps. One screen, no scrolling, signature
/// to Présage's positioning.
struct AntiFeaturePanel: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer().frame(height: 20)

            VStack(alignment: .leading, spacing: 8) {
                WhisperLabel(text: "What Présage is not")
                Text("No streaks. No badges. No coach.")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .kerning(-0.6)
                    .lineSpacing(2)
            }

            VStack(alignment: .leading, spacing: 16) {
                antiRow(strikethrough: "No virtual pet to feed.")
                antiRow(strikethrough: "No streak to break.")
                antiRow(strikethrough: "No AI life coach.")
                antiRow(strikethrough: "No leveling up.")
                antiRow(strikethrough: "No celebration on a correct prediction.")
            }

            Rectangle()
                .fill(DS.Palette.separator)
                .frame(height: 1)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 14) {
                WhisperLabel(text: "What Présage is")
                affirmRow("A score for the gap between what you said and what happened.")
                affirmRow("Resolution-before-reveal so you can't anchor on your own bet.")
                affirmRow("A wall of shame pointing at your blind spots.")
            }

            Spacer()

            PariButton("Show me the truth") {
                onContinue()
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .background(DS.Palette.surfacePrimary.ignoresSafeArea())
    }

    private func antiRow(strikethrough text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DS.Palette.accentSecondary)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DS.Palette.textSecondary)
                .strikethrough(true, color: DS.Palette.textTertiary)
        }
    }

    private func affirmRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(DS.Palette.accent)
                .frame(width: 6, height: 6)
                .padding(.top, 7)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DS.Palette.textPrimary)
        }
    }
}
