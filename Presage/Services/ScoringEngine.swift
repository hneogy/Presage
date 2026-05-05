import Foundation

enum ScoringEngine {

    /// Probabilities are clamped to this open interval before any log/Brier
    /// math, so a corrupted or out-of-range confidence can never produce
    /// NaN, ±Inf, or a negative Brier. Lower than the previous 0.001 so
    /// confident predictions don't all collapse onto the same log floor.
    private static let probabilityEpsilon: Double = 1e-6

    private static func clampedForecast(_ confidencePercent: Int) -> Double {
        let raw = Double(confidencePercent) / 100.0
        return min(1.0 - probabilityEpsilon, max(probabilityEpsilon, raw))
    }

    static func brierScore(confidencePercent: Int, outcome: Bool) -> Double {
        let forecast = clampedForecast(confidencePercent)
        let actual: Double = outcome ? 1.0 : 0.0
        return (forecast - actual) * (forecast - actual)
    }

    static func logScore(confidencePercent: Int, outcome: Bool) -> Double {
        let forecast = clampedForecast(confidencePercent)
        let p = outcome ? forecast : (1.0 - forecast)
        return log2(p)
    }

    /// Single chokepoint for "what counts toward your Brier?" — yes/no
    /// resolved AND not fudged. Every aggregator routes through this so
    /// no caller can accidentally bypass the fudge filter.
    ///
    /// Bug history: prior to audit pass 12, only `CalibrationCache` did
    /// the fudge filter. Every other caller (HomeView, Annual Report,
    /// Correlation Engine, Coach, Compare Brier intent) silently mixed
    /// fudged predictions into their aggregates, producing numbers that
    /// disagreed with the headline Brier. Now centralized.
    private static func headlineScorable(_ predictions: [Prediction]) -> [Prediction] {
        predictions.filter {
            !$0.isFudged && !$0.isTrainingMode && ($0.outcome == .yes || $0.outcome == .no)
        }
    }

    static func aggregateBrier(_ predictions: [Prediction]) -> Double? {
        let scorable = headlineScorable(predictions)
        guard !scorable.isEmpty else { return nil }
        let total = scorable.reduce(0.0) { sum, p in
            sum + brierScore(confidencePercent: p.confidencePercent, outcome: p.outcome == .yes)
        }
        return total / Double(scorable.count)
    }

    static func aggregateLog(_ predictions: [Prediction]) -> Double? {
        let scorable = headlineScorable(predictions)
        guard !scorable.isEmpty else { return nil }
        let total = scorable.reduce(0.0) { sum, p in
            sum + logScore(confidencePercent: p.confidencePercent, outcome: p.outcome == .yes)
        }
        return total / Double(scorable.count)
    }

    static func buildCalibrationBuckets(_ predictions: [Prediction]) -> [CalibrationBucket] {
        let scorable = headlineScorable(predictions)
        let grouped = Dictionary(grouping: scorable) { ConfidenceLevel.snap($0.confidencePercent) }

        return ConfidenceLevel.allSteps.map { step in
            let preds = grouped[step] ?? []
            let hits = preds.filter { $0.outcome == .yes }.count
            return CalibrationBucket(
                confidencePercent: step,
                predictionCount: preds.count,
                hitCount: hits
            )
        }
    }

    static func categoryScores(_ predictions: [Prediction]) -> [CategoryScore] {
        let scorable = headlineScorable(predictions)
        let grouped = Dictionary(grouping: scorable) { $0.categoryRaw }

        return grouped.compactMap { key, preds in
            guard let brier = aggregateBrier(preds),
                  let log = aggregateLog(preds) else { return nil }
            return CategoryScore(category: key, brierScore: brier, logScore: log, count: preds.count)
        }
    }

    static func horizonScores(_ predictions: [Prediction]) -> [HorizonScore] {
        let scorable = headlineScorable(predictions)
        let grouped = Dictionary(grouping: scorable) { $0.horizon }

        return grouped.compactMap { horizon, preds in
            guard let brier = aggregateBrier(preds) else { return nil }
            return HorizonScore(horizon: horizon.rawValue, brierScore: brier, count: preds.count)
        }
    }

    static func moodScores(_ predictions: [Prediction]) -> [MoodScore] {
        // Pair each prediction with its non-nil mood once, then group on
        // the value — avoids force-unwrapping inside the grouping closure.
        let scorable = headlineScorable(predictions)
            .compactMap { p -> (String, Prediction)? in
                guard let mood = p.moodTagRaw else { return nil }
                return (mood, p)
            }
        let grouped = Dictionary(grouping: scorable) { $0.0 }
            .mapValues { $0.map(\.1) }

        return grouped.compactMap { mood, preds in
            guard let brier = aggregateBrier(preds) else { return nil }
            return MoodScore(mood: mood, brierScore: brier, count: preds.count)
        }
    }

    /// Wall of shame — high-confidence misses that the user didn't pre-disclose
    /// via the fudge button. Showing fudged predictions on the wall of shame
    /// would be punitive after the user already confessed; they're excluded.
    static func worstMisses(_ predictions: [Prediction], minConfidence: Int = 80, limit: Int = 5) -> [Prediction] {
        // Training-mode predictions never count toward real calibration
        // (see headlineScorable for the contract). They likewise can't
        // earn a spot on the wall of shame — that would be punitive for
        // a deliberate practice answer the user wasn't claiming as a
        // real forecast.
        predictions
            .filter {
                !$0.isFudged
                && !$0.isTrainingMode
                && $0.outcome == .no
                && $0.confidencePercent >= minConfidence
            }
            .sorted { brierScore(confidencePercent: $0.confidencePercent, outcome: false) >
                      brierScore(confidencePercent: $1.confidencePercent, outcome: false) }
            .prefix(limit)
            .map { $0 }
    }

    static func averageConfidence(_ predictions: [Prediction]) -> Int? {
        let real = predictions.filter { !$0.isTrainingMode }
        guard !real.isEmpty else { return nil }
        let total = real.reduce(0) { $0 + $1.confidencePercent }
        return total / real.count
    }

    static func hitRate(_ predictions: [Prediction]) -> Double? {
        let scorable = headlineScorable(predictions)
        guard !scorable.isEmpty else { return nil }
        let hits = scorable.filter { $0.outcome == .yes }.count
        return Double(hits) / Double(scorable.count)
    }

    // MARK: - Numeric / Range predictions

    /// Score a numeric range prediction using the "did the actual fall in
    /// my interval?" heuristic, weighted by confidence. A tighter range
    /// that contains the actual scores better than a wide one.
    static func numericBrier(low: Double, high: Double, actual: Double, confidence: Int) -> Double {
        let inRange = actual >= low && actual <= high
        let forecast = Double(confidence) / 100.0
        let outcome: Double = inRange ? 1.0 : 0.0
        return (forecast - outcome) * (forecast - outcome)
    }

    // MARK: - Multiple-choice

    /// Score a multiple-choice prediction: probability assigned to the
    /// correct answer, scored as a Brier loss.
    static func multipleChoiceBrier(choices: [PredictionChoice], correctLabel: String) -> Double {
        var sumSquared = 0.0
        for choice in choices {
            let p = Double(choice.confidencePercent) / 100.0
            let actual = choice.label == correctLabel ? 1.0 : 0.0
            sumSquared += (p - actual) * (p - actual)
        }
        return sumSquared
    }

    // MARK: - Benchmarks

    /// Public benchmark constants — pulled from published research.
    /// Used to anchor the user against external reference points.
    enum Benchmark {
        static let metaculusBrier: Double = 0.111      // Metaculus public Brier
        static let manifoldBrier: Double = 0.168       // Manifold Markets public Brier
        static let randomGuess: Double = 0.25          // 50/50 every time
        static let superforecaster: Double = 0.10      // Tetlock superforecasters approx
        static let typicalAdult: Double = 0.20         // Untrained baseline approx
    }

    /// Returns a label describing where the user sits relative to known benchmarks.
    static func benchmarkTier(for brier: Double) -> String {
        switch brier {
        case ..<Benchmark.superforecaster: return "Superforecaster tier"
        case ..<Benchmark.metaculusBrier:  return "Better than Metaculus"
        case ..<Benchmark.manifoldBrier:   return "Better than Manifold"
        case ..<Benchmark.typicalAdult:    return "Above average"
        case ..<Benchmark.randomGuess:     return "Below average"
        default:                           return "Worse than guessing"
        }
    }
}
