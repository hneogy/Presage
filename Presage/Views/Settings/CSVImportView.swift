import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CSVImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var pickerPresented = false
    @State private var resultMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    WhisperLabel(text: "Import")
                    Text("Coming from elsewhere?")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(DS.Palette.textPrimary)
                        .kerning(-0.4)
                }

                Text("Présage can import CSV exports from PredictionBook, Fatebook, or any spreadsheet with a `claim` column. Your data stays local.")
                    .font(.system(size: 15))
                    .foregroundStyle(DS.Palette.textSecondary)
                    .lineSpacing(2)

                PariButton("Choose a CSV file", icon: "doc.text") {
                    pickerPresented = true
                }

                if let message = resultMessage {
                    PariCard {
                        Text(message)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DS.Palette.textPrimary)
                    }
                }

                supportedFormatsCard
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(DS.Palette.surfacePrimary)
        .navigationTitle("Import")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $pickerPresented,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handlePicked(result)
        }
    }

    private var supportedFormatsCard: some View {
        PariCard {
            VStack(alignment: .leading, spacing: 12) {
                WhisperLabel(text: "Supported")
                ForEach(["Fatebook export (.csv)",
                         "PredictionBook export (.csv)",
                         "Generic spreadsheet with a `claim` column"], id: \.self) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DS.Palette.accent)
                            .font(.system(size: 14))
                        Text(item)
                            .font(.system(size: 14))
                            .foregroundStyle(DS.Palette.textSecondary)
                    }
                }
            }
        }
    }

    private func handlePicked(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url),
              let csv = String(data: data, encoding: .utf8) else {
            resultMessage = "Couldn't read file."
            return
        }

        let r = CSVImporter.import(csv: csv, into: context)
        let formatName: String
        switch r.format {
        case .fatebook: formatName = "Fatebook"
        case .predictionBook: formatName = "PredictionBook"
        case .generic: formatName = "Generic CSV"
        case .unknown: formatName = "Unknown format"
        }
        resultMessage = "Imported \(r.imported) predictions from \(formatName). Skipped \(r.skipped) rows."
        HapticService.success()
    }
}
