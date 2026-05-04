import SwiftUI
import PDFKit

/// Generates a beautiful printable Calibration Report PDF from the user's
/// year of predictions. Premium-tier monetization. Runs entirely on-device.
@MainActor
enum AnnualReportRenderer {

    struct YearData {
        let year: Int
        let totalResolved: Int
        let brierScore: Double?
        let categoryBreakdown: [CategoryScore]
        let worstMisses: [Prediction]
        let bestPredictions: [Prediction]
        let calibrationBuckets: [CalibrationBucket]
    }

    static func gather(predictions: [Prediction], snapshot: CalibrationSnapshot?, year: Int = Calendar.current.component(.year, from: .now)) -> YearData {
        let cal = Calendar.current
        let yearPredictions = predictions.filter { p in
            guard let resolvedAt = p.resolvedAt else { return false }
            return cal.component(.year, from: resolvedAt) == year
        }
        let scorable = yearPredictions.filter {
            !$0.isFudged && ($0.outcome == .yes || $0.outcome == .no)
        }
        let worst = ScoringEngine.worstMisses(yearPredictions, minConfidence: 80, limit: 5)
        let best = scorable.filter {
            ($0.outcome == .yes && $0.confidencePercent >= 80) ||
            ($0.outcome == .no && $0.confidencePercent <= 60)
        }
        .sorted {
            ScoringEngine.brierScore(confidencePercent: $0.confidencePercent, outcome: $0.outcome == .yes) <
            ScoringEngine.brierScore(confidencePercent: $1.confidencePercent, outcome: $1.outcome == .yes)
        }
        .prefix(5)

        return YearData(
            year: year,
            totalResolved: scorable.count,
            brierScore: ScoringEngine.aggregateBrier(scorable),
            categoryBreakdown: ScoringEngine.categoryScores(scorable),
            worstMisses: worst,
            bestPredictions: Array(best),
            calibrationBuckets: ScoringEngine.buildCalibrationBuckets(scorable)
        )
    }

    static func renderPDF(data: YearData) -> Data? {
        let pageSize = CGSize(width: 612, height: 792)  // US Letter

        let renderer = ImageRenderer(content: AnnualReportPages(data: data))
        renderer.proposedSize = ProposedViewSize(pageSize)

        // Render via the SwiftUI ImageRenderer's CGContext path. This
        // produces a true vector PDF (text remains text, not bitmap)
        // instead of rasterizing the SwiftUI view to a UIImage and
        // embedding the bitmap. Pre-pass-14 used the UIImage path —
        // PDFs printed blurry and couldn't be text-selected.
        var output: Data?
        renderer.render { size, drawCallback in
            let format = UIGraphicsPDFRendererFormat()
            let pdfRenderer = UIGraphicsPDFRenderer(
                bounds: CGRect(origin: .zero, size: pageSize),
                format: format
            )
            output = pdfRenderer.pdfData { ctx in
                ctx.beginPage()
                let cgContext = ctx.cgContext
                // Center the rendered content within the page in case
                // the SwiftUI view's intrinsic size differs from page size.
                let dx = (pageSize.width - size.width) / 2
                let dy = (pageSize.height - size.height) / 2
                cgContext.translateBy(x: dx, y: dy)
                drawCallback(cgContext)
            }
        }
        return output
    }
}

private struct AnnualReportPages: View {
    let data: AnnualReportRenderer.YearData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x0E1A24), Color(hex: 0x070D12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(alignment: .leading, spacing: 14) {
                    Text("CALIBRATION REPORT")
                        .font(.system(size: 12, weight: .semibold))
                        .kerning(2.5)
                        .foregroundStyle(Color(hex: 0x8B9AA6))
                    Text("\(String(data.year))")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xF2EDE6))
                    Text("Présage · A year of predictions, scored.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: 0x8B9AA6))
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: 220)

            VStack(alignment: .leading, spacing: 16) {
                section("BRIER SCORE") {
                    HStack(alignment: .firstTextBaseline) {
                        Text(brierString)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: 0x1F7878))
                        Spacer()
                        if let b = data.brierScore {
                            Text(ScoringEngine.benchmarkTier(for: b))
                                .font(.system(size: 12, weight: .semibold))
                                .kerning(1.2)
                                .foregroundStyle(Color(hex: 0xD27D5A))
                        }
                    }
                    Text("across \(data.totalResolved) resolved predictions")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0x6E7980))
                }

                Divider()

                section("BY CATEGORY") {
                    VStack(spacing: 6) {
                        ForEach(data.categoryBreakdown, id: \.category) { c in
                            HStack {
                                if let cat = PredictionCategory(rawValue: c.category) {
                                    Text(cat.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                Spacer()
                                Text(PariFormat.brier(c.brierScore))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: 0x1F7878))
                                Text("· n=\(c.count)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: 0x6E7980))
                            }
                        }
                    }
                }

                Divider()

                section("WORST MISSES") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(data.worstMisses) { p in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\u{201C}\(p.claim)\u{201D}")
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                Text("Said \(p.confidencePercent)% — was wrong")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(hex: 0xD27D5A))
                            }
                        }
                    }
                }

                Spacer()

                Text("Generated by Présage · pari.app")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: 0xA8AFB5))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(36)
        }
        .frame(width: 612, height: 792)
        .background(Color(hex: 0xF6F4F0))
    }

    private var brierString: String {
        guard let b = data.brierScore else { return "—" }
        return PariFormat.brier(b)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .kerning(1.8)
                .foregroundStyle(Color(hex: 0x6E7980))
            content()
        }
    }
}
