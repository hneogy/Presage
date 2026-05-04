import Foundation

/// Generates an Obsidian-compatible markdown vault — one .md file per
/// prediction with YAML frontmatter, plus an index.md and a calibration.md.
/// Bidirectional `[[wikilinks]]` connect related predictions by category.
enum MarkdownVaultExporter {

    struct ExportedFile {
        let filename: String
        let content: String
    }

    static func export(predictions: [Prediction], snapshot: CalibrationSnapshot?) -> [ExportedFile] {
        var files: [ExportedFile] = []
        files.append(indexFile(predictions: predictions, snapshot: snapshot))
        files.append(calibrationFile(snapshot: snapshot))
        for prediction in predictions {
            files.append(predictionFile(prediction))
        }
        return files
    }

    /// Writes all files to a temporary directory and returns the directory URL.
    /// Cleans up older exports before writing so /tmp doesn't accumulate
    /// across repeated exports.
    static func writeVault(predictions: [Prediction], snapshot: CalibrationSnapshot?) throws -> URL {
        let fm = FileManager.default
        cleanupOlderExports(in: fm.temporaryDirectory, fm: fm)

        let stamp = Int(Date().timeIntervalSince1970)
        let dir = fm.temporaryDirectory.appendingPathComponent("pari-vault-\(stamp)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        for file in export(predictions: predictions, snapshot: snapshot) {
            let url = dir.appendingPathComponent(file.filename)
            try file.content.write(to: url, atomically: true, encoding: .utf8)
        }
        return dir
    }

    private static func cleanupOlderExports(in tmp: URL, fm: FileManager) {
        guard let contents = try? fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) else { return }
        for url in contents where url.lastPathComponent.hasPrefix("pari-vault-") {
            try? fm.removeItem(at: url)
        }
    }

    // MARK: - File generators

    private static func predictionFile(_ p: Prediction) -> ExportedFile {
        let safeName = p.claim
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .prefix(60)
        let filename = "\(safeName)-\(p.id.uuidString.prefix(8)).md"
        let outcomeStr = p.outcome?.rawValue ?? "unresolved"
        let resolvedStr = p.resolvedAt?.formatted(.iso8601) ?? "null"
        let brier: String = {
            if let outcome = p.outcome, outcome == .yes || outcome == .no {
                // Frontmatter values are machine-readable. YAML / Obsidian
                // expect period-separated decimals regardless of user
                // locale, so explicitly use a fixed C locale here.
                return String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"),
                              ScoringEngine.brierScore(
                    confidencePercent: p.confidencePercent,
                    outcome: outcome == .yes
                ))
            }
            return "null"
        }()

        let frontmatter = """
        ---
        id: \(p.id.uuidString)
        confidence: \(p.confidencePercent)
        category: \(p.category.rawValue)
        created: \(p.createdAt.formatted(.iso8601))
        resolves: \(p.resolutionDate.formatted(.iso8601))
        resolved: \(resolvedStr)
        outcome: \(outcomeStr)
        brier: \(brier)
        tags: [pari, \(p.category.rawValue)]
        ---
        """

        var body = "# \(p.claim)\n\n"
        body += "**Confidence:** \(p.confidencePercent)%  \n"
        body += "**Resolves:** \(p.resolutionDate.formatted(.dateTime.month(.wide).day().year()))\n\n"
        body += "## Resolution Criteria\n\n\(p.resolutionCriteria)\n\n"
        if let reasoning = p.reasoning {
            body += "## Reasoning\n\n\(reasoning)\n\n"
        }
        if let risks = p.risks {
            body += "## Risks\n\n\(risks)\n\n"
        }
        if let notes = p.postResolutionNotes {
            body += "## Post-resolution notes\n\n\(notes)\n\n"
        }
        body += "\n## Related\n\n[[\(p.category.displayName)]]\n"

        return ExportedFile(filename: filename, content: frontmatter + "\n\n" + body)
    }

    private static func indexFile(predictions: [Prediction], snapshot: CalibrationSnapshot?) -> ExportedFile {
        var content = "# Présage Vault\n\n"
        content += "Exported \(Date.now.formatted(.dateTime.year().month(.wide).day().hour().minute()))  \n"
        content += "Total predictions: \(predictions.count)\n\n"
        if let snap = snapshot, let brier = snap.brierScore {
            content += "## Brier Score: \(PariFormat.brier(brier))\n"
            content += "(\(snap.totalResolved) resolved · \(ScoringEngine.benchmarkTier(for: brier)))\n\n"
        }

        let byCategory = Dictionary(grouping: predictions) { $0.category }
        for cat in PredictionCategory.allCases where byCategory[cat] != nil {
            content += "## \(cat.displayName)\n\n"
            for p in byCategory[cat] ?? [] {
                let safeName = p.claim.prefix(60)
                content += "- [[\(safeName)-\(p.id.uuidString.prefix(8))]] · \(p.confidencePercent)%\n"
            }
            content += "\n"
        }
        return ExportedFile(filename: "index.md", content: content)
    }

    private static func calibrationFile(snapshot: CalibrationSnapshot?) -> ExportedFile {
        var content = "# Calibration\n\n"
        guard let snap = snapshot else {
            content += "No calibration data yet.\n"
            return ExportedFile(filename: "calibration.md", content: content)
        }
        content += "## Buckets\n\n"
        content += "| Confidence | Predictions | Hit rate |\n|---|---|---|\n"
        for bucket in snap.buckets where bucket.predictionCount > 0 {
            content += "| \(bucket.confidencePercent)% | \(bucket.predictionCount) | \(bucket.hitRatePercent)% |\n"
        }
        return ExportedFile(filename: "calibration.md", content: content)
    }
}
