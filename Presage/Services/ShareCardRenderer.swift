import SwiftUI
import os

/// Renders a beautiful resolved-prediction card as a UIImage suitable
/// for sharing on social. Privacy-respecting — user picks what to share.
@MainActor
enum ShareCardRenderer {

    /// Conservative pre-flight memory floor. Below this we skip the
    /// 2x render rather than risk a memory-pressure jetsam on older
    /// devices. The static card is ~30 MB at 2x; we leave 3x headroom.
    private static let memoryFloorBytes: UInt64 = 100 * 1024 * 1024

    static func render(prediction: Prediction, brierScore: Double?) -> UIImage? {
        // Probe available memory before instantiating the ImageRenderer.
        // ImageRenderer with a 1080x1080 view at 2x scale allocates a
        // bitmap that briefly doubles its working set, which is enough
        // to push older iPhones over the jetsam line under load.
        let available = os_proc_available_memory()
        if available > 0 && UInt64(available) < memoryFloorBytes {
            return nil
        }

        let view = ShareCard(prediction: prediction, overallBrier: brierScore)
            .frame(width: 1080, height: 1080)
        let renderer = ImageRenderer(content: view)
        // Cap the scale at 1x on devices below the comfortable memory
        // headroom. The result is a 1080x1080 image either way; only
        // the bitmap working set differs.
        let availableUInt = UInt64(max(available, 0))
        renderer.scale = availableUInt < memoryFloorBytes * 2 ? 1.0 : 2.0
        return renderer.uiImage
    }
}

/// The visual share card. 1:1 aspect, fits Twitter/Threads/IG.
struct ShareCard: View {
    let prediction: Prediction
    let overallBrier: Double?

    var body: some View {
        ZStack {
            // Atmospheric background
            LinearGradient(
                colors: [Color(hex: 0x0E1A24), Color(hex: 0x070D12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color(hex: 0x2FA8A8).opacity(0.25), .clear],
                center: UnitPoint(x: 0.7, y: 0.3),
                startRadius: 0,
                endRadius: 600
            )

            VStack(alignment: .leading, spacing: 40) {
                // Top — Présage wordmark
                HStack {
                    Text("Présage")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF2EDE6))
                    Circle()
                        .fill(Color(hex: 0x2FA8A8))
                        .frame(width: 12, height: 12)
                        .padding(.bottom, 4)
                    Spacer()
                    Text(prediction.category.displayName.uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .kerning(2.0)
                        .foregroundStyle(Color(hex: 0x8B9AA6))
                }

                // The score moment
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("I PREDICTED")
                            .font(.system(size: 18, weight: .semibold))
                            .kerning(2.0)
                            .foregroundStyle(Color(hex: 0x8B9AA6))
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("\(prediction.confidencePercent)")
                                .foregroundStyle(Color(hex: 0xF2EDE6))
                            Text("%")
                                .foregroundStyle(Color(hex: 0xF4A88A))
                        }
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("REALITY SAID")
                            .font(.system(size: 18, weight: .semibold))
                            .kerning(2.0)
                            .foregroundStyle(Color(hex: 0x8B9AA6))
                        Text(outcomeLabel)
                            .font(.system(size: 96, weight: .bold, design: .rounded))
                            .foregroundStyle(outcomeColor)
                    }
                }

                Rectangle()
                    .fill(Color(hex: 0x1A252E))
                    .frame(height: 1)

                // The claim
                VStack(alignment: .leading, spacing: 14) {
                    Text("THE CLAIM")
                        .font(.system(size: 16, weight: .semibold))
                        .kerning(2.0)
                        .foregroundStyle(Color(hex: 0x4A5A66))
                    Text("\u{201C}\(prediction.claim)\u{201D}")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Color(hex: 0xF2EDE6))
                        .lineLimit(4)
                }

                Spacer()

                // Footer with overall Brier
                if let overall = overallBrier {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MY BRIER SCORE")
                                .font(.system(size: 13, weight: .semibold))
                                .kerning(1.8)
                                .foregroundStyle(Color(hex: 0x4A5A66))
                            Text(PariFormat.brier(overall))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: 0xF2EDE6))
                                .monospacedDigit()
                        }
                        Spacer()
                        Text(ScoringEngine.benchmarkTier(for: overall))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x2FA8A8))
                    }
                }

                Text("pari.app — calibrate your beliefs")
                    .font(.system(size: 14, weight: .medium))
                    .kerning(1.0)
                    .foregroundStyle(Color(hex: 0x4A5A66))
                    .frame(maxWidth: .infinity)
            }
            .padding(72)
        }
        .frame(width: 1080, height: 1080)
        .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
    }

    private var outcomeLabel: String {
        switch prediction.outcome {
        case .yes: "YES"
        case .no: "NO"
        case .ambiguous: "—"
        default: "—"
        }
    }

    private var outcomeColor: Color {
        switch prediction.outcome {
        case .yes: Color(hex: 0x2FA8A8)
        case .no: Color(hex: 0xF4A88A)
        default: Color(hex: 0x8B9AA6)
        }
    }
}
