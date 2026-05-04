import SwiftUI
import Charts

struct CalibrationTrendChart: View {
    let predictions: [Prediction]

    private var rollingScores: [(date: Date, score: Double)] {
        let scorable = predictions
            .filter { $0.outcome == .yes || $0.outcome == .no }
            .sorted { ($0.resolvedAt ?? .distantPast) < ($1.resolvedAt ?? .distantPast) }

        guard scorable.count >= 20 else { return [] }

        var result: [(Date, Double)] = []
        for i in 19..<scorable.count {
            let window = Array(scorable[(i - 19)...i])
            if let brier = ScoringEngine.aggregateBrier(window),
               let date = window.last?.resolvedAt {
                result.append((date, brier))
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
