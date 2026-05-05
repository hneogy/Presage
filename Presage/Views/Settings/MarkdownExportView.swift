import SwiftUI
import SwiftData

struct MarkdownExportView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var context

    @Query(sort: \Prediction.createdAt, order: .reverse) private var predictions: [Prediction]
    @Query(sort: \CalibrationSnapshot.computedAt, order: .reverse) private var snapshots: [CalibrationSnapshot]

    @State private var resultMessage: String? = nil
    @State private var lastVaultURL: URL? = nil

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

                if let url = lastVaultURL {
                    PariButton("Share again", style: .secondary, icon: "square.and.arrow.up") {
                        presentShare(folder: url)
                    }
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
            lastVaultURL = url
            resultMessage = "Vault written to: \(url.lastPathComponent). Use “Share again” below to re-send to Obsidian or Files anytime."
            presentShare(folder: url)
        } catch {
            resultMessage = "Couldn't write the vault: \(error.localizedDescription). Try again, or free up some disk space and retry."
        }
    }

    private func presentShare(folder: URL) {
        let activity = UIActivityViewController(activityItems: [folder], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            resultMessage = "Couldn't open the share sheet right now. Tap Share again to retry."
            return
        }
        var presenting = root
        while let next = presenting.presentedViewController { presenting = next }
        presenting.present(activity, animated: true)
    }
}
