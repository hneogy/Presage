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

        // Suffix the per-export directory with a UUID rather than just
        // the wall clock — two exports inside the same second won't
        // collide, and a hostile process on the device can't predict
        // the path well enough to land a TOCTOU swap before our
        // createDirectory call lands.
        let stamp = Int(Date().timeIntervalSince1970)
        let unique = UUID().uuidString.prefix(8)
        let dir = fm.temporaryDirectory.appendingPathComponent(
            "pari-vault-\(stamp)-\(unique)",
            isDirectory: true
        )
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        // If any file write fails, scrub the partial directory so we
        // don't leave half-written exports in /tmp masquerading as
        // completed vaults the user might re-open.
        do {
            for file in export(predictions: predictions, snapshot: snapshot) {
                let url = dir.appendingPathComponent(file.filename)
                try file.content.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            try? fm.removeItem(at: dir)
            throw error
        }
        return dir
    }

    /// Remove vault directories older than 24 hours; the user has
    /// already shared what they wanted out of /tmp by then. Older
    /// scans were "kill everything matching pari-vault-*", which is
    /// fine but doesn't guard against a future bug where the most
    /// recent vault hasn't been shared yet — gate on age instead.
    private static func cleanupOlderExports(in tmp: URL, fm: FileManager) {
        guard let contents = try? fm.contentsOfDirectory(
            at: tmp,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        for url in contents where url.lastPathComponent.hasPrefix("pari-vault-") {
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            if let created, created > cutoff { continue }
            try? fm.removeItem(at: url)
        }
    }

    // MARK: - File generators

    /// Whitelist filename sanitizer. Any character that isn't a letter,
    /// digit, space, dash, or underscore becomes `-`, then we collapse
    /// runs and strip leading dots to neutralize `..`, `.git`, hidden
    /// files, and Windows path tricks (`\`, drive letters, reserved
    /// names). The UUID suffix guarantees uniqueness even if two claims
    /// sanitize to the same string.
    private static func sanitizeForFilename(_ raw: String) -> String {
        let allowed: Set<Character> = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_")
        var cleaned = raw.map { allowed.contains($0) ? $0 : "-" }.reduce(into: "") { acc, ch in
            // Collapse runs of dashes so "I/O/foo" doesn't become "I-O-foo"-with-runs.
            if ch == "-", acc.last == "-" { return }
            acc.append(ch)
        }
        // Trim leading dashes/spaces/dots so the filename can't start
        // with `.` (hidden) or `-` (mistaken for a CLI flag in scripts
        // that walk the export).
        while let first = cleaned.first, first == "-" || first == " " || first == "." {
            cleaned.removeFirst()
        }
        // Trim trailing whitespace/dashes for cleanliness.
        while let last = cleaned.last, last == "-" || last == " " || last == "." {
            cleaned.removeLast()
        }
        return cleaned.isEmpty ? "prediction" : String(cleaned.prefix(60))
    }

    private static func predictionFile(_ p: Prediction) -> ExportedFile {
        let safeName = sanitizeForFilename(p.claim)
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
        // Pin the export timestamp to ISO 8601 so vaults shared between
        // users — or version-controlled across machines — don't shift
        // month names from English to Arabic/Japanese/etc. with the
        // exporter's locale. Frontmatter dates already use ISO 8601;
        // the index header was the last locale-leaky surface.
        content += "Exported \(Date.now.formatted(.iso8601))  \n"
        content += "Total predictions: \(predictions.count)\n\n"
        if let snap = snapshot, let brier = snap.brierScore {
            content += "## Brier Score: \(PariFormat.brier(brier))\n"
            content += "(\(snap.totalResolved) resolved · \(ScoringEngine.benchmarkTier(for: brier)))\n\n"
        }

        let byCategory = Dictionary(grouping: predictions) { $0.category }
        for cat in PredictionCategory.allCases where byCategory[cat] != nil {
            content += "## \(cat.displayName)\n\n"
            for p in byCategory[cat] ?? [] {
                // Use the same sanitized filename root as predictionFile()
                // so the [[wikilink]] in index.md actually resolves to the
                // generated .md file.
                let safeName = sanitizeForFilename(p.claim)
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
