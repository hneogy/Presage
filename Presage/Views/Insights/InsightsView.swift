import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Query(filter: #Predicate<CalibrationSnapshot> { _ in true },
           sort: \CalibrationSnapshot.computedAt, order: .reverse)
    private var snapshots: [CalibrationSnapshot]

    @Query(filter: #Predicate<Prediction> { $0.outcomeRaw != nil },
           sort: \Prediction.resolvedAt, order: .reverse)
    private var resolvedPredictions: [Prediction]

    @Query(sort: \Prediction.createdAt)
    private var allPredictions: [Prediction]

    private var snapshot: CalibrationSnapshot? { snapshots.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                header
                if resolvedPredictions.isEmpty {
                    PariEmptyState(
                        icon: "brain.head.profile",
                        title: "No insights yet",
                        message: "Resolve predictions to unlock insights about your calibration."
                    )
                    .padding(.top, DS.Space.xxxxl)
                    .frame(maxWidth: .infinity)
                } else {
                    benchmarkSection
                    correlationsSection
                    yearInPixelsSection
                    categorySection
                    horizonSection
                    moodSection
                    trendSection
                    wallOfShameSection
                    distributionSection
                }
            }
            .padding(.horizontal, DS.Space.base)
            .padding(.top, DS.Space.lg)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.insights(colorScheme))
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: "Calibration")
            Text("Insights")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.6)
        }
        .padding(.top, 16)
    }

    // MARK: - Correlations (the Bearable-style insights)

    @ViewBuilder
    private var correlationsSection: some View {
        let insights = CorrelationEngine.analyze(resolvedPredictions)
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Patterns we found")
                    .font(DS.Typo.titleLarge)
                    .foregroundStyle(DS.Palette.textPrimary)

                ForEach(insights.prefix(5)) { insight in
                    PariCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(insight.kind.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .semibold))
                                    .kerning(1.5)
                                    .foregroundStyle(insight.kind == .overconfidence ? DS.Palette.accentSecondary : DS.Palette.accent)
                                Spacer()
                                Text(insight.strength.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .semibold))
                                    .kerning(1.0)
                                    .foregroundStyle(DS.Palette.textTertiary)
                            }
                            Text(insight.headline)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DS.Palette.textPrimary)
                            Text(insight.detail)
                                .font(.system(size: 13))
                                .foregroundStyle(DS.Palette.textSecondary)
                                .lineSpacing(2)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var yearInPixelsSection: some View {
        if resolvedPredictions.count >= 5 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your year")
                    .font(DS.Typo.titleLarge)
                    .foregroundStyle(DS.Palette.textPrimary)

                PariCard {
                    CalendarHeatmap(predictions: resolvedPredictions)
                }
            }
        }
    }

    // MARK: - Benchmarks (Calibration City–style)

    @ViewBuilder
    private var benchmarkSection: some View {
        if let snap = snapshot, let brier = snap.brierScore {
            VStack(alignment: .leading, spacing: 12) {
                Text("Where you stand")
                    .font(DS.Typo.titleLarge)
                    .foregroundStyle(DS.Palette.textPrimary)

                PariCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                WhisperLabel(text: "You")
                                Text(PariFormat.brier(brier))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(DS.Palette.accent)
                                    .monospacedDigit()
                            }
                            Spacer()
                            Text(ScoringEngine.benchmarkTier(for: brier))
                                .font(.system(size: 12, weight: .semibold))
                                .kerning(1.0)
                                .foregroundStyle(DS.Palette.accentSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(DS.Palette.accentSecondaryMuted)
                                )
                        }

                        Divider().background(DS.Palette.separator)

                        VStack(spacing: 10) {
                            benchmarkRow(label: "Superforecasters",
                                        score: ScoringEngine.Benchmark.superforecaster,
                                        userScore: brier)
                            benchmarkRow(label: "Metaculus",
                                        score: ScoringEngine.Benchmark.metaculusBrier,
                                        userScore: brier)
                            benchmarkRow(label: "Manifold Markets",
                                        score: ScoringEngine.Benchmark.manifoldBrier,
                                        userScore: brier)
                            benchmarkRow(label: "Typical adult",
                                        score: ScoringEngine.Benchmark.typicalAdult,
                                        userScore: brier)
                            benchmarkRow(label: "Random guessing",
                                        score: ScoringEngine.Benchmark.randomGuess,
                                        userScore: brier)
                        }
                    }
                }
            }
        }
    }

    private func benchmarkRow(label: String, score: Double, userScore: Double) -> some View {
        let beating = userScore < score
        return HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.Palette.textSecondary)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: beating ? "arrow.up" : "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(beating ? DS.Palette.accent : DS.Palette.accentSecondary)
                Text(PariFormat.brier(score))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Palette.textTertiary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - By Category

    @ViewBuilder
    private var categorySection: some View {
        let scores = snapshot?.categoryScores ?? []

        VStack(alignment: .leading, spacing: DS.Space.md) {
            Text("By category")
                .font(DS.Typo.titleLarge)
                .foregroundStyle(DS.Palette.textPrimary)

            if scores.isEmpty {
                needMoreDataCard(5, label: "per category")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Space.sm) {
                        ForEach(scores, id: \.category) { score in
                            CategoryScoreCard(score: score)
                        }
                    }
                }
            }
        }
    }

    // MARK: - By Time Horizon

    @ViewBuilder
    private var horizonSection: some View {
        let scores = snapshot?.horizonScores ?? []

        VStack(alignment: .leading, spacing: DS.Space.md) {
            Text("By time horizon")
                .font(DS.Typo.titleLarge)
                .foregroundStyle(DS.Palette.textPrimary)

            if scores.isEmpty {
                needMoreDataCard(5, label: "per horizon")
            } else {
                ForEach(scores, id: \.horizon) { score in
                    HorizonScoreRow(score: score)
                }
            }
        }
    }

    // MARK: - By Mood

    @ViewBuilder
    private var moodSection: some View {
        let scores = snapshot?.moodScores ?? []

        if !scores.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                Text("By mood at prediction time")
                    .font(DS.Typo.titleLarge)
                    .foregroundStyle(DS.Palette.textPrimary)

                ForEach(scores, id: \.mood) { score in
                    MoodScoreRow(score: score)
                }
            }
        }
    }

    // MARK: - Calibration Trend

    @ViewBuilder
    private var trendSection: some View {
        if resolvedPredictions.count >= 20 {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                Text("Your calibration journey")
                    .font(DS.Typo.titleLarge)
                    .foregroundStyle(DS.Palette.textPrimary)

                CalibrationTrendChart(predictions: resolvedPredictions)
                    .frame(height: 200)
            }
        }
    }

    // MARK: - Wall of Shame

    @ViewBuilder
    private var wallOfShameSection: some View {
        let worst = ScoringEngine.worstMisses(resolvedPredictions)

        VStack(alignment: .leading, spacing: DS.Space.md) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("Worst misses")
                    .font(DS.Typo.titleLarge)
                    .foregroundStyle(DS.Palette.textPrimary)
                Text("High confidence, wrong answer")
                    .font(DS.Typo.callout)
                    .foregroundStyle(DS.Palette.textTertiary)
            }

            if worst.isEmpty {
                PariCard {
                    Text("No high-confidence misses yet.")
                        .font(DS.Typo.callout)
                        .foregroundStyle(DS.Palette.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(worst) { prediction in
                    WallOfShameItem(prediction: prediction)
                }
            }
        }
    }

    // MARK: - Confidence Distribution

    @ViewBuilder
    private var distributionSection: some View {
        if allPredictions.count >= 10 {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                Text("How you predict")
                    .font(DS.Typo.titleLarge)
                    .foregroundStyle(DS.Palette.textPrimary)

                ConfidenceDistributionChart(predictions: allPredictions)
                    .frame(height: 120)
            }
        }
    }

    // MARK: - Helper

    private func needMoreDataCard(_ count: Int, label: String) -> some View {
        PariCard {
            Text("Need at least \(count) resolved predictions \(label)")
                .font(DS.Typo.callout)
                .foregroundStyle(DS.Palette.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Sub-views

struct CategoryScoreCard: View {
    let score: CategoryScore

    private var categoryName: String {
        PredictionCategory(rawValue: score.category)?.displayName ?? score.category
    }

    var body: some View {
        PariCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Text(categoryName)
                    .font(DS.Typo.titleMedium)
                    .foregroundStyle(DS.Palette.textPrimary)

                Text(PariFormat.brier(score.brierScore))
                    .font(DS.Typo.titleMedium)
                    .foregroundStyle(DS.Palette.accent)

                Text("n=\(score.count)")
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.Palette.textTertiary)
            }
        }
        .frame(width: 160)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(categoryName), Brier score \(PariFormat.brier(score.brierScore)), \(score.count) resolved predictions")
        .accessibilityCustomContent("Category", categoryName)
        .accessibilityCustomContent("Brier score", PariFormat.brier(score.brierScore))
        .accessibilityCustomContent("Sample size", "\(score.count)")
    }
}

struct HorizonScoreRow: View {
    let score: HorizonScore

    var body: some View {
        PariCard {
            HStack {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text(score.horizon)
                        .font(DS.Typo.bodyEmphasized)
                        .foregroundStyle(DS.Palette.textPrimary)
                    Text("n=\(score.count)")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.Palette.textTertiary)
                }
                Spacer()
                Text(PariFormat.brier(score.brierScore))
                    .font(DS.Typo.titleMedium)
                    .foregroundStyle(DS.Palette.accent)
            }
        }
    }
}

struct MoodScoreRow: View {
    let score: MoodScore

    var body: some View {
        PariCard {
            HStack {
                if let mood = MoodTag(rawValue: score.mood) {
                    Text(mood.displayName)
                        .font(DS.Typo.bodyEmphasized)
                        .foregroundStyle(DS.Palette.textPrimary)
                }
                Spacer()
                Text(PariFormat.brier(score.brierScore))
                    .font(DS.Typo.titleMedium)
                    .foregroundStyle(DS.Palette.accent)
                Text("n=\(score.count)")
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.Palette.textTertiary)
            }
        }
    }
}

struct WallOfShameItem: View {
    let prediction: Prediction

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    var body: some View {
        PariCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(alignment: .top, spacing: DS.Space.sm) {
                    if differentiate {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .foregroundStyle(DS.Palette.semanticNo)
                    }
                    Text(prediction.claim)
                        .font(DS.Typo.body)
                        .foregroundStyle(DS.Palette.textPrimary)
                        .lineLimit(2)
                }

                HStack {
                    Text("\(prediction.confidencePercent)% confident")
                        .font(DS.Typo.captionEmphasized)
                        .foregroundStyle(DS.Palette.semanticNo)

                    Spacer()

                    if let date = prediction.resolvedAt {
                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.Palette.textTertiary)
                    }
                }
            }
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(DS.Palette.semanticNo)
                .frame(width: 3)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: DS.Radius.md,
                    bottomLeadingRadius: DS.Radius.md
                ))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("High confidence miss: \(prediction.claim). Predicted \(prediction.confidencePercent) percent. Resolved no.")
    }
}
