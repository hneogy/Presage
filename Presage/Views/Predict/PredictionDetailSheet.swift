import SwiftUI

struct PredictionDetailSheet: View {
    @Environment(PariEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    let prediction: Prediction

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    Text(prediction.claim)
                        .font(DS.Typo.titleLarge)
                        .foregroundStyle(DS.Palette.textPrimary)

                    infoGrid

                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Text("What counts as yes:")
                            .font(DS.Typo.footnote)
                            .foregroundStyle(DS.Palette.textTertiary)
                        Text(prediction.resolutionCriteria)
                            .font(DS.Typo.body)
                            .foregroundStyle(DS.Palette.textSecondary)
                    }

                    if prediction.isDue {
                        PariButton("Resolve") {
                            dismiss()
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(300))
                                engine.resolvingPrediction = prediction
                            }
                        }
                    }
                }
                .padding(DS.Space.lg)
            }
            .background(DS.Palette.surfacePrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DS.Palette.accent)
                }
            }
        }
    }

    private var infoGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: DS.Space.lg, verticalSpacing: DS.Space.md) {
            GridRow {
                infoCell("Confidence", value: "\(prediction.confidencePercent)%")
                infoCell("Created", value: prediction.createdAt.formatted(.dateTime.month(.abbreviated).day()))
            }
            GridRow {
                infoCell("Resolves", value: prediction.resolutionDate.formatted(.dateTime.month(.abbreviated).day()))
                infoCell("Category", value: prediction.category.displayName)
            }
        }
    }

    private func infoCell(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(label)
                .font(DS.Typo.footnote)
                .foregroundStyle(DS.Palette.textTertiary)
            Text(value)
                .font(DS.Typo.bodyEmphasized)
                .foregroundStyle(DS.Palette.textPrimary)
        }
    }
}
