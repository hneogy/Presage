import Foundation
import SwiftData

/// Imports predictions from competing tools' CSV exports.
/// Auto-detects format from header row.
enum CSVImporter {

    enum SourceFormat {
        case fatebook
        case predictionBook
        case generic       // generic spreadsheet
        case unknown
    }

    /// Hard ceiling on CSV body size. A real PredictionBook/Fatebook export
    /// is at most a few MB; capping at 50MB rejects accidentally-uploaded
    /// massive files (or a hostile pasteboard injection from an automation)
    /// before we allocate ~Nx that for `components(separatedBy:)`.
    static let maxCSVBytes = 50 * 1024 * 1024

    /// Hard ceiling on the number of rows we'll attempt to import in one
    /// pass. Prevents a 50MB file of single-character lines from
    /// producing tens of millions of CSV rows that swamp SwiftData.
    static let maxCSVRows = 100_000

    @MainActor
    static func `import`(csv: String, into context: ModelContext) -> ImportResult {
        guard csv.utf8.count <= maxCSVBytes else {
            return ImportResult(imported: 0, skipped: 0, format: .unknown)
        }

        // Strip a UTF-8 BOM if present. Excel and some web exporters
        // emit `\u{FEFF}` as the first character — without this, the
        // BOM gets concatenated with the first column name and the
        // header detection fails to recognize "claim"/"forecast".
        var input = csv
        if input.first == "\u{FEFF}" {
            input.removeFirst()
        }

        let rows = parseCSVRows(input)
        guard rows.count >= 2 else {
            return ImportResult(imported: 0, skipped: 0, format: .unknown)
        }
        // Cap row count so a flood of rows can't exhaust memory on the
        // SwiftData insert path.
        let rowsToProcess = rows.count > maxCSVRows
            ? Array(rows.prefix(maxCSVRows))
            : rows

        let headerCols = rowsToProcess[0]
        let header = headerCols.joined(separator: ",").lowercased()
        let format = detectFormat(header: header)

        var imported = 0
        var skipped = 0

        for row in rowsToProcess.dropFirst() {
            guard let prediction = parseRow(columns: row, headerCols: headerCols, format: format) else {
                skipped += 1
                continue
            }
            context.insert(prediction)
            imported += 1
        }

        try? context.save()
        for _ in 0..<imported {
            PariEngine.recordCreation()
        }
        return ImportResult(imported: imported, skipped: skipped, format: format)
    }

    private static func detectFormat(header: String) -> SourceFormat {
        if header.contains("forecast") && header.contains("resolution") {
            return .fatebook
        }
        if header.contains("predictionbook") || header.contains("credence") {
            return .predictionBook
        }
        if header.contains("claim") || header.contains("question") {
            return .generic
        }
        return .unknown
    }

    private static func sanitize(_ input: String, maxLength: Int) -> String {
        let stripped = input.unicodeScalars.filter { scalar in
            scalar.value >= 0x20 || scalar == "\n"
        }
        let cleaned = String(String.UnicodeScalarView(stripped))
        return String(cleaned.prefix(maxLength))
    }

    private static func parseRow(columns: [String], headerCols: [String], format: SourceFormat) -> Prediction? {
        // headerCols is parsed once by the caller and reused for every
        // row — re-parsing on each row was an O(rows * columns) hot path
        // on large imports.
        func value(for keys: [String]) -> String? {
            for key in keys {
                if let idx = headerCols.firstIndex(where: { $0.lowercased() == key.lowercased() }),
                   idx < columns.count {
                    return columns[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return nil
        }

        guard let rawClaim = value(for: ["title", "claim", "question", "prediction"]),
              !rawClaim.isEmpty else { return nil }
        let claim = sanitize(rawClaim, maxLength: 500)

        let confidenceStr = value(for: ["forecast", "credence", "confidence", "probability"]) ?? "0.7"
        let confidenceFraction = Double(confidenceStr.replacingOccurrences(of: "%", with: "")) ?? 70
        let confidence: Int = confidenceFraction <= 1
            ? Int((confidenceFraction * 100).rounded())
            : Int(confidenceFraction.rounded())
        let snapped = ConfidenceLevel.snap(max(50, min(99, confidence)))

        let resolutionDateStr = value(for: ["resolveby", "resolve_by", "resolution date", "deadline"]) ?? ""
        let resolutionDate = parseDate(resolutionDateStr)
            ?? Calendar.current.date(byAdding: .day, value: 30, to: .now)
            ?? Date(timeIntervalSinceNow: 30 * 86400)

        let rawCriteria = value(for: ["criteria", "resolution criteria", "notes"]) ?? "Imported"
        let criteria = sanitize(rawCriteria, maxLength: 1000)

        let prediction = Prediction(
            claim: claim,
            resolutionCriteria: criteria,
            confidencePercent: snapped,
            resolutionDate: resolutionDate,
            category: .external,
            tags: ["imported"]
        )

        // If resolved in source, carry over
        if let outcomeStr = value(for: ["resolution", "outcome", "result"])?.lowercased() {
            if outcomeStr.contains("yes") || outcomeStr.contains("true") {
                prediction.outcome = .yes
                prediction.resolvedAt = .now
            } else if outcomeStr.contains("no") || outcomeStr.contains("false") {
                prediction.outcome = .no
                prediction.resolvedAt = .now
            } else if outcomeStr.contains("ambiguous") {
                prediction.outcome = .ambiguous
                prediction.resolvedAt = .now
            }
        }

        return prediction
    }

    private static func parseDate(_ str: String) -> Date? {
        let formatters = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd'T'HH:mm:ssZ"]
        for fmt in formatters {
            let f = DateFormatter()
            f.dateFormat = fmt
            if let date = f.date(from: str) { return date }
        }
        return ISO8601DateFormatter().date(from: str)
    }

    /// RFC 4180-ish CSV parser. Splits the entire CSV body into rows of
    /// fields in a single pass. Critically:
    ///   • A `""` inside a quoted field becomes a literal `"`
    ///   • A newline inside a quoted field stays inside the field rather
    ///     than starting a new row
    ///   • `\r\n` and lone `\r` are normalized to `\n` between rows
    ///   • Empty trailing rows are skipped
    /// The previous line-by-line parser corrupted any export with
    /// claims that contained quote characters or hard line breaks.
    private static func parseCSVRows(_ input: String) -> [[String]] {
        var rows: [[String]] = []
        var current: [String] = []
        var field = ""
        var inQuotes = false

        let scalars = Array(input.unicodeScalars)
        var i = 0
        while i < scalars.count {
            let c = scalars[i]
            if inQuotes {
                if c == "\"" {
                    // Lookahead: `""` inside quotes is an escaped quote.
                    if i + 1 < scalars.count, scalars[i + 1] == "\"" {
                        field.append("\"")
                        i += 2
                        continue
                    }
                    inQuotes = false
                    i += 1
                    continue
                }
                field.unicodeScalars.append(c)
                i += 1
            } else {
                if c == "\"" {
                    inQuotes = true
                    i += 1
                } else if c == "," {
                    current.append(field)
                    field = ""
                    i += 1
                } else if c == "\r" || c == "\n" {
                    // Treat \r\n as a single row separator.
                    if c == "\r", i + 1 < scalars.count, scalars[i + 1] == "\n" {
                        i += 2
                    } else {
                        i += 1
                    }
                    current.append(field)
                    field = ""
                    if !current.allSatisfy({ $0.isEmpty }) {
                        rows.append(current)
                    }
                    current = []
                } else {
                    field.unicodeScalars.append(c)
                    i += 1
                }
            }
        }
        // Trailing field / row (file may not end with a newline).
        current.append(field)
        if !current.allSatisfy({ $0.isEmpty }) {
            rows.append(current)
        }
        return rows
    }

    struct ImportResult {
        let imported: Int
        let skipped: Int
        let format: SourceFormat
    }
}
