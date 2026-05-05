import SwiftUI
import Charts

struct CalibrationTrendChart: View {
    let predictions: [Prediction]

    /// Cap the rolling-window line at the most recent N scorable
    /// predictions. Past ~600 points the catmull-rom interpolation in
    /// Charts becomes the dominant cost on every body re-eval, which
    /// turns scrolling Insights into a slideshow on older devices. The
    /// chart's purpose is "is the trend up or down?", so older data
    /// gets summarized into the long-window average rather than every
    /// individual rolling point.
    private static let maxRollingPoints = 600

    private var rollingScores: [(date: Date, score: Double)] {
        let scorable = predictions
            .filter { $0.outcome == .yes || $0.outcome == .no }
            .sorted { ($0.resolvedAt ?? .distantPast) < ($1.resolvedAt ?? .distantPast) }

        guard scorable.count >= 20 else { return [] }

        // Compute the rolling Brier with an O(n) sliding window over a
        // bounded tail rather than re-aggregating every sub-array.
        // Old code rebuilt the window+aggregate per index which was
        // O(n * windowSize) and quadratic in practice on long histories.
        let tail = scorable.suffix(Self.maxRollingPoints + 19)
        let arr = Array(tail)
        guard arr.count >= 20 else { return [] }

        var sum: Double = 0
        for i in 0..<20 {
            sum += ScoringEngine.brierScore(
                confidencePercent: arr[i].confidencePercent,
                outcome: arr[i].outcome == .yes
            )
        }

        var result: [(Date, Double)] = []
        if let firstDate = arr[19].resolvedAt {
            result.append((firstDate, sum / 20.0))
        }
        for i in 20..<arr.count {
            // Slide the window: drop oldest, add newest.
            let drop = arr[i - 20]
            sum -= ScoringEngine.brierScore(
                confidencePercent: drop.confidencePercent,
                outcome: drop.outcome == .yes
            )
            sum += ScoringEngine.brierScore(
                confidencePercent: arr[i].confidencePercent,
                outcome: arr[i].outcome == .yes
            )
            if let date = arr[i].resolvedAt {
                result.append((date, sum / 20.0))
            }
        }
        return result
    }

    var body: some View {
        Chart {
            RuleMark(y: .value("Random", 0.25))
                .foregroundStyle(DS.Palette.textTertiary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .trailing, alignment: .leading) {
                    Text("random")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.Palette.textTertiary)
                }

            ForEach(Array(rollingScores.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Brier", point.score)
                )
                .foregroundStyle(DS.Palette.accent)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYScale(domain: 0...0.5)
        .chartYAxis {
            AxisMarks(values: [0, 0.1, 0.25, 0.5]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DS.Palette.separator)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(PariFormat.twoFraction(v))
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.Palette.textTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DS.Palette.separator)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.abbreviated)))
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.Palette.textTertiary)
                    }
                }
            }
        }
        .chartLegend(.hidden)
    }
}
