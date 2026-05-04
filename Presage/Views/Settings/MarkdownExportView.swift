import SwiftUI
import SwiftData

struct MarkdownExportView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var context

    @Query(sort: \Prediction.createdAt, order: .reverse) private var predictions: [Prediction]
    @Query(sort: \CalibrationSnapshot.computedAt, order: .reverse) private var snapshots: [CalibrationSnapshot]

    @State private var resultMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    WhisperLabel(text: "Portable")
                    Text("Obsidian / Markdown export")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(DS.Palette.textPrimary)
                        .kerning(-0.4)
                }

                Text("Generate a vault folder where each prediction is a markdown file with YAML frontmatter and `[[wikilinks]]`. Drop into Obsidian, Logseq, or any Markdown PKM tool.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Palette.textSecondary)
                    .lineSpacing(2)

                PariButton("Export vault") {
                    exportVault()
                }

                if let msg = resultMessage {
                    PariCard {
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Palette.textPrimary)
                            .lineSpacing(2)
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(DS.Palette.surfacePrimary)
        .navigationTitle("Markdown export")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exportVault() {
        guard !predictions.isEmpty else {
            resultMessage = "Nothing to export yet — make a few predictions first, then come back."
            return
        }
        do {
            let url = try MarkdownVaultExporter.writeVault(predictions: predictions, snapshot: snapshots.first)
            resultMessage = "Vault written to: \(url.lastPathComponent)\n\nPress Share to send to Obsidian or Files."
            presentShare(folder: url)
        } catch {
            resultMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func presentShare(folder: URL) {
        let activity = UIActivityViewController(activityItems: [folder], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        var presenting = root
        while let next = presenting.presentedViewController { presenting = next }
        presenting.present(activity, animated: true)
    }
}
