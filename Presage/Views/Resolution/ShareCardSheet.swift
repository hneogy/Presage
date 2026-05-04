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

                    ShareCard(prediction: prediction, overallBrier: overallBrier)
                        .frame(width: 320, height: 320)
                        .scaleEffect(0.296)   // 1080 → 320
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
