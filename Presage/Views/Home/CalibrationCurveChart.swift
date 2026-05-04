import SwiftUI
import Charts

struct CalibrationCurveChart: View {
    let buckets: [CalibrationBucket]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var animationProgress: CGFloat = 0
    @State private var pointsAppeared: Bool = false

    private var activeBuckets: [CalibrationBucket] {
        buckets.filter { $0.predictionCount > 0 }
    }

    var body: some View {
        Chart {
            // 1. Subtle perfect-calibration zone band (lighter than the dashed line)
            ForEach(ConfidenceLevel.allSteps, id: \.self) { pct in
                LineMark(
                    x: .value("Confidence", pct),
                    y: .value("Hit Rate", pct),
                    series: .value("Series", "Perfect")
                )
                .foregroundStyle(DS.Palette.chartPerfect.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 5]))
                .interpolationMethod(.linear)
            }

            // 2. User curve — gradient fill underneath
            if activeBuckets.count > 1 {
                ForEach(activeBuckets) { bucket in
                    let adjustedRate = Double(bucket.hitRatePercent) * animationProgress
                    AreaMark(
                        x: .value("Confidence", bucket.confidencePercent),
                        yStart: .value("Floor", 0),
                        yEnd: .value("Hit Rate", Int(adjustedRate))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DS.Palette.accent.opacity(0.25),
                                DS.Palette.accent.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }

            // 3. User curve line
            ForEach(activeBuckets) { bucket in
                let adjustedRate = Double(bucket.hitRatePercent) * animationProgress
                if activeBuckets.count > 1 {
                    LineMark(
                        x: .value("Confidence", bucket.confidencePercent),
                        y: .value("Hit Rate", Int(adjustedRate)),
                        series: .value("Series", "User")
                    )
                    .foregroundStyle(curveGradient)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }
            }

            // 4. Glow halos on points
            ForEach(activeBuckets) { bucket in
                let adjustedRate = Double(bucket.hitRatePercent) * animationProgress
                PointMark(
                    x: .value("Confidence", bucket.confidencePercent),
                    y: .value("Hit Rate", Int(adjustedRate))
                )
                .foregroundStyle(DS.Palette.accent.opacity(0.3))
                .symbolSize(CGFloat(max(bucket.predictionCount, 1)) * 80)
                .opacity(pointsAppeared ? 1 : 0)
            }

            // 5. Solid dots
            ForEach(activeBuckets) { bucket in
                let adjustedRate = Double(bucket.hitRatePercent) * animationProgress
                PointMark(
                    x: .value("Confidence", bucket.confidencePercent),
                    y: .value("Hit Rate", Int(adjustedRate))
                )
                .foregroundStyle(DS.Palette.accent)
                .symbolSize(CGFloat(max(bucket.predictionCount, 1)) * 24)
                .opacity(pointsAppeared ? 1 : 0)
            }
        }
        .chartXScale(domain: 45...100)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: [50, 60, 70, 80, 90, 99]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DS.Palette.separator.opacity(0.5))
                AxisValueLabel {
                    if let pct = value.as(Int.self) {
                        VStack(spacing: 3) {
                            Text("\(pct)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(DS.Palette.textTertiary)
                                .monospacedDigit()
                            if let bucket = buckets.first(where: { $0.confidencePercent == pct }),
                               bucket.predictionCount > 0 {
                                Text("\(bucket.predictionCount)")
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundStyle(DS.Palette.textTertiary.opacity(0.5))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DS.Palette.separator.opacity(0.5))
                AxisValueLabel {
                    if let pct = value.as(Int.self) {
                        Text("\(pct)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(DS.Palette.textTertiary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .accessibilityLabel("Calibration curve")
        .accessibilityValue(accessibilitySummary)
        .accessibilityChartDescriptor(self)
        .onAppear {
            if reduceMotion {
                animationProgress = 1
                pointsAppeared = true
            } else {
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.9)) {
                    animationProgress = 1
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
                    pointsAppeared = true
                }
            }
        }
    }

    private var curveGradient: LinearGradient {
        LinearGradient(
            colors: [DS.Palette.accent, DS.Palette.accent.opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var accessibilitySummary: String {
        if activeBuckets.isEmpty {
            return "No data yet. Resolve predictions to populate the curve."
        }
        let segments = activeBuckets.map {
            "At \($0.confidencePercent) percent confidence, you were correct \($0.hitRatePercent) percent of the time across \($0.predictionCount) predictions."
        }
        return segments.joined(separator: " ")
    }
}

extension CalibrationCurveChart: AXChartDescriptorRepresentable {
    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Confidence",
            range: 45...100,
            gridlinePositions: [50, 60, 70, 80, 90, 99]
        ) { value in "\(Int(value)) percent" }

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Actual hit rate",
            range: 0...100,
            gridlinePositions: [0, 25, 50, 75, 100]
        ) { value in "\(Int(value)) percent" }

        let dataPoints = activeBuckets.map {
            AXDataPoint(
                x: Double($0.confidencePercent),
                y: Double($0.hitRatePercent),
                additionalValues: [],
                label: "n=\($0.predictionCount)"
            )
        }

        return AXChartDescriptor(
            title: "Calibration curve",
            summary: accessibilitySummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(name: "Your calibration", isContinuous: false, dataPoints: dataPoints)]
        )
    }
}
