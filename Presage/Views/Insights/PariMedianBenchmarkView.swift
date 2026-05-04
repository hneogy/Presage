import SwiftUI
import SwiftData

/// The "Pari Median" public benchmark visualization. Shows where the user
/// sits on the canonical forecasting accuracy map.
struct PariMedianBenchmarkView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Query(filter: #Predicate<CalibrationSnapshot> { _ in true },
           sort: \CalibrationSnapshot.computedAt, order: .reverse)
    private var snapshots: [CalibrationSnapshot]

    private var userBrier: Double? { snapshots.first?.brierScore }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let b = userBrier {
                    userCard(brier: b)
                    benchmarkLadder(userBrier: b)
                    methodologyCard
                } else {
                    PariCard {
                        Text("Resolve at least one prediction to see your position on the canonical forecasting map.")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.Palette.textSecondary)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.insights(colorScheme))
        .navigationTitle("Benchmark")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: "ForecastBench · Public benchmark")
            Text("Where you stand")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.5)
            Text("Brier scores across the canonical forecasting field. Lower is better. Présage median = \(PariFormat.brier(PariMedianBenchmark.pariMedian)).")
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.textSecondary)
                .lineSpacing(2)
                .padding(.top, 4)
        }
    }

    private func userCard(brier: Double) -> some View {
        PariCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        WhisperLabel(text: "Your Brier")
                        Text(PariFormat.brier(brier))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Palette.accent)
                            .monospacedDigit()
                    }
                    Spacer()
                    Text("RANK #\(PariMedianBenchmark.userPosition(brier: brier))")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(DS.Palette.accentSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(DS.Palette.accentSecondaryMuted))
                }
                Text(PariMedianBenchmark.comparison(brier: brier))
                    .font(.system(size: 14))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .lineSpacing(2)
            }
        }
    }

    private func benchmarkLadder(userBrier: Double) -> some View {
        var allPoints = PariMedianBenchmark.canonical
        allPoints.append(PariMedianBenchmark.BenchmarkPoint(
            name: "Présage median",
            brierScore: PariMedianBenchmark.pariMedian,
            citation: "Présage aggregate, opt-in",
            isPariUser: false
        ))
        allPoints.append(PariMedianBenchmark.BenchmarkPoint(
            name: "You",
            brierScore: userBrier,
            citation: "This device",
            isPariUser: true
        ))
        let sorted = allPoints.sorted { $0.brierScore < $1.brierScore }

        return VStack(alignment: .leading, spacing: 12) {
            Text("The ladder")
                .font(DS.Typo.titleLarge)
                .foregroundStyle(DS.Palette.textPrimary)

            VStack(spacing: 6) {
                ForEach(sorted) { point in
                    benchmarkRow(point)
                }
            }
        }
    }

    private func benchmarkRow(_ point: PariMedianBenchmark.BenchmarkPoint) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(point.isPariUser ? DS.Palette.accent : DS.Palette.textTertiary)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(point.name)
                    .font(.system(size: 14, weight: point.isPariUser ? .semibold : .regular))
                    .foregroundStyle(point.isPariUser ? DS.Palette.accent : DS.Palette.textPrimary)
                Text(point.citation)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Palette.textTertiary)
            }
            Spacer()
            Text(PariFormat.brier(point.brierScore))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(point.isPariUser ? DS.Palette.accent : DS.Palette.textSecondary)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(point.isPariUser
                      ? DS.Palette.accentMuted
                      : DS.Palette.surfaceSecondary)
        )
    }

    private var methodologyCard: some View {
        PariCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                WhisperLabel(text: "Methodology")
                Text("Brier scores on the canonical forecasting field, sourced from ForecastBench (ICLR 2025), Metaculus public stats, Manifold platform-wide aggregates, and Tetlock's Good Judgment research. Présage median is computed quarterly from anonymous opt-in user submissions.")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Palette.textTertiary)
                    .lineSpacing(2)
            }
        }
    }
}
