import SwiftUI
import SwiftData

struct PredictionDetailSheet: View {
    @Environment(PariEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let prediction: Prediction
    /// Re-fetched copy that's refreshed on appear and whenever the
    /// underlying store changes. Reading from the captured `prediction`
    /// reference can read invalidated memory if another view (or
    /// CloudKit sync) deletes the row while this sheet is on screen —
    /// `liveCopy` is always fetched against the current store, and we
    /// fall back to the deleted-record UI when it goes nil.
    @State private var liveCopy: Prediction?

    private func refreshLiveCopy() {
        let id = prediction.id
        let descriptor = FetchDescriptor<Prediction>(
            predicate: #Predicate<Prediction> { $0.id == id }
        )
        liveCopy = (try? context.fetch(descriptor).first)
    }

    var body: some View {
        NavigationStack {
            if let live = liveCopy {
                contentView(for: live)
            } else {
                deletedFallback
            }
        }
        .onAppear { refreshLiveCopy() }
    }

    private var deletedFallback: some View {
        VStack(spacing: DS.Space.md) {
            Image(systemName: "trash.slash")
                .font(.system(size: 36))
                .foregroundStyle(DS.Palette.textTertiary)
            Text("This prediction was deleted.")
                .font(DS.Typo.body)
                .foregroundStyle(DS.Palette.textSecondary)
            PariButton("Done") { dismiss() }
                .padding(.horizontal, DS.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Palette.surfacePrimary)
    }

    private func contentView(for live: Prediction) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                Text(live.claim)
                    .font(DS.Typo.titleLarge)
                    .foregroundStyle(DS.Palette.textPrimary)

                infoGrid(for: live)

                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text("What counts as yes:")
                        .font(DS.Typo.footnote)
                        .foregroundStyle(DS.Palette.textTertiary)
                    Text(live.resolutionCriteria)
                        .font(DS.Typo.body)
                        .foregroundStyle(DS.Palette.textSecondary)
                }

                if live.isDue {
                    PariButton("Resolve") {
                        engine.pendingDeepLinkPredictionID = live.id
                        dismiss()
                    }
                } else {
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Text("Available on \(live.resolutionDate.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(DS.Typo.footnote)
                            .foregroundStyle(DS.Palette.textTertiary)
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

    private func infoGrid(for live: Prediction) -> some View {
        Grid(alignment: .leading, horizontalSpacing: DS.Space.lg, verticalSpacing: DS.Space.md) {
            GridRow {
                infoCell("Confidence", value: "\(live.confidencePercent)%")
                infoCell("Created", value: live.createdAt.formatted(.dateTime.month(.abbreviated).day()))
            }
            GridRow {
                infoCell("Resolves", value: live.resolutionDate.formatted(.dateTime.month(.abbreviated).day()))
                infoCell("Category", value: live.category.displayName)
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
