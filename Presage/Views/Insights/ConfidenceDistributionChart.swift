import SwiftUI
import Charts

struct ConfidenceDistributionChart: View {
    let predictions: [Prediction]

    private var distribution: [(bucket: Int, count: Int)] {
        let grouped = Dictionary(grouping: predictions) { ConfidenceLevel.snap($0.confidencePercent) }
        return ConfidenceLevel.allSteps.map { step in
            (bucket: step, count: grouped[step]?.count ?? 0)
        }
    }

    private var modalBucket: Int {
        distribution.max(by: { $0.count < $1.count })?.bucket ?? 70
    }

    var body: some View {
        Chart(distribution, id: \.bucket) { item in
            BarMark(
                x: .value("Confidence", "\(item.bucket)%"),
                y: .value("Count", item.count)
            )
            .foregroundStyle(item.bucket == modalBucket ? DS.Palette.accent : DS.Palette.accentMuted)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.Palette.textTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DS.Palette.separator)
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.Palette.textTertiary)
                    }
                }
            }
        }
        .chartLegend(.hidden)
    }
}
