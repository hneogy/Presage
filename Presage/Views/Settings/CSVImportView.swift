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
        guard url.startAccessingSecurityScopedResource() else {
            resultMessage = "Couldn't access this file. Try moving it to the Files app first."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else {
            resultMessage = "Couldn't read this file. It may be in use by another app."
            return
        }

        // Reject files above the importer's hard ceiling before we
        // allocate a String for them — String(data:encoding:) doubles
        // memory for UTF-16 and we don't want a careless drop-in to OOM
        // the device.
        if data.count > CSVImporter.maxCSVBytes {
            resultMessage = "This CSV is too large (over 50 MB). Try splitting it before importing."
            return
        }

        // Try the most common encodings before giving up. Excel on Windows
        // often emits Windows-1252 or UTF-16-LE; macOS Numbers and Google
        // Sheets default to UTF-8.
        let encodings: [(String.Encoding, String)] = [
            (.utf8, "UTF-8"),
            (.utf16, "UTF-16"),
            (.utf16LittleEndian, "UTF-16 LE"),
            (.windowsCP1252, "Windows-1252"),
            (.isoLatin1, "ISO-8859-1")
        ]
        var csv: String? = nil
        for (enc, _) in encodings {
            if let s = String(data: data, encoding: enc), !s.isEmpty {
                csv = s
                break
            }
        }
        guard let csv else {
            resultMessage = "Couldn't decode this file. Try re-saving it as UTF-8 CSV in your spreadsheet app."
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
        if r.imported == 0 && r.skipped > 0 {
            resultMessage = "Couldn't read any predictions from this file. \(r.skipped) rows skipped — check that there's a `claim` or `question` column."
        } else if r.skipped > 0 {
            resultMessage = "Imported \(r.imported) predictions from \(formatName). Skipped \(r.skipped) rows that were missing required columns."
        } else {
            resultMessage = "Imported \(r.imported) predictions from \(formatName)."
        }
        HapticService.success()
    }
}
