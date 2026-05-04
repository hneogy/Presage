import SwiftUI

/// A claim input bundled with a "Flip" affordance. Users who want to
/// express <50% confidence can tap Flip to invert the claim's negation,
/// making it expressible as a >50% confidence in the opposite outcome.
struct ClaimInput: View {
    @Binding var text: String
    var placeholder: String = "I will finish the book by Friday"

    @State private var showFlipHint = false
    @State private var flipPulse = false

    var canFlip: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PariInput(
                placeholder: placeholder,
                text: $text,
                isMultiline: true
            )

            HStack(spacing: 10) {
                flipButton

                Spacer()

                if showFlipHint {
                    Text("Same belief, opposite framing")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Palette.accentSecondary)
                        .transition(.opacity)
                }
            }
        }
    }

    private var flipButton: some View {
        Button {
            performFlip()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(flipPulse ? 180 : 0))
                Text("Flip claim")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(canFlip ? DS.Palette.accent : DS.Palette.textTertiary)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                Capsule(style: .continuous)
                    .fill(canFlip ? DS.Palette.accentMuted : DS.Palette.surfaceTertiary.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .disabled(!canFlip)
        .accessibilityLabel("Flip claim")
        .accessibilityHint("Inverts your claim's wording so you can express the opposite belief")
    }

    private func performFlip() {
        guard canFlip, let flipped = ClaimFlipper.flip(text) else { return }
        HapticService.medium()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            flipPulse.toggle()
            text = flipped
            showFlipHint = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { showFlipHint = false }
        }
    }
}
