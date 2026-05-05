import SwiftUI

/// Shareable card view shown after resolution. Renders the prediction
/// as a 1080×1080 image and offers share options.
struct ShareCardSheet: View {
    let prediction: Prediction
    let overallBrier: Double?
    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Share this resolution")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(DS.Palette.textPrimary)

                    // ShareCard is intrinsically 1080×1080 — clamp to a
                        // 320×320 layout footprint, scale the rendered
                        // content down to fit. The outer .frame() reserves
                        // the layout slot; .scaleEffect() shrinks the
                        // rendered pixels without touching the layout.
                        // (Previous double-frame was redundant — scaleEffect
                        // doesn't consume layout, so a second frame after it
                        // was a no-op.)
                    ShareCard(prediction: prediction, overallBrier: overallBrier)
                        .scaleEffect(0.296)
                        .frame(width: 320, height: 320)

                    PariButton("Share") {
                        if renderedImage == nil {
                            renderedImage = ShareCardRenderer.render(
                                prediction: prediction,
                                brierScore: overallBrier
                            )
                        }
                        if let image = renderedImage {
                            presentShareSheet(image: image)
                        }
                    }

                    Text("Generated as a 1080×1080 image. Présage never uploads — sharing is fully under your control.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Palette.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 24)
            }
            .background(DS.Palette.surfacePrimary)
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DS.Palette.accent)
                }
            }
        }
    }

    private func presentShareSheet(image: UIImage) {
        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        var presenting = root
        while let next = presenting.presentedViewController { presenting = next }
        presenting.present(activity, animated: true)
    }
}
