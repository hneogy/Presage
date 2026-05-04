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

    @MainActor
    static func `import`(csv: String, into context: ModelContext) -> ImportResult {
        let lines = csv.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else {
            return ImportResult(imported: 0, skipped: 0, format: .unknown)
        }

        let header = lines[0].lowercased()
        let format = detectFormat(header: header)

        var imported = 0
        var skipped = 0

        for line in lines.dropFirst() {
            let columns = parseCSVLine(line)
            guard let prediction = parseRow(columns: columns, header: header, format: format) else {
                skipped += 1
                continue
            }
            context.insert(prediction)
            imported += 1
        }

        try? context.save()
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

    private static func parseRow(columns: [String], header: String, format: SourceFormat) -> Prediction? {
        let headerCols = parseCSVLine(header)

        func value(for keys: [String]) -> String? {
            for key in keys {
                if let idx = headerCols.firstIndex(where: { $0.lowercased() == key.lowercased() }),
                   idx < columns.count {
                    return columns[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return nil
        }

        guard let claim = value(for: ["title", "claim", "question", "prediction"]),
              !claim.isEmpty else { return nil }

        let confidenceStr = value(for: ["forecast", "credence", "confidence", "probability"]) ?? "0.7"
        let confidenceFraction = Double(confidenceStr.replacingOccurrences(of: "%", with: "")) ?? 70
        let confidence: Int = confidenceFraction <= 1
            ? Int((confidenceFraction * 100).rounded())
            : Int(confidenceFraction.rounded())
        let snapped = ConfidenceLevel.snap(max(50, min(99, confidence)))

        let resolutionDateStr = value(for: ["resolveby", "resolve_by", "resolution date", "deadline"]) ?? ""
        let resolutionDate = parseDate(resolutionDateStr)
            ?? Calendar.current.date(byAdding: .day, value: 30, to: .now)!

        let criteria = value(for: ["criteria", "resolution criteria", "notes"]) ?? "Imported"

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

    /// Tiny CSV parser — handles quoted fields containing commas.
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }

    struct ImportResult {
        let imported: Int
        let skipped: Int
        let format: SourceFormat
    }
}
