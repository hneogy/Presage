import Foundation

/// Bearable-style correlation engine. Mines the user's prediction history
/// for "if X then Y" patterns ("you're more overconfident in the morning",
/// "your gym predictions are 20% worse when mood is low").
///
/// No external service — all analysis runs locally on the user's device.
enum CorrelationEngine {

    struct Insight: Identifiable, Hashable {
        var id: UUID = UUID()
        let headline: String
        let detail: String
        let strength: Strength
        let kind: Kind

        enum Strength: String { case strong, moderate, weak }
        enum Kind: String { case overconfidence, underconfidence, accuracy, pattern }
    }

    static func analyze(_ predictions: [Prediction]) -> [Insight] {
        let scorable = predictions.filter {
            ($0.outcome == .yes || $0.outcome == .no) && !$0.isFudged
        }
        guard scorable.count >= 10 else { return [] }

        var insights: [Insight] = []
        insights.append(contentsOf: timeOfDayCorrelation(scorable))
        insights.append(contentsOf: moodCorrelation(scorable))
        insights.append(contentsOf: categoryCorrelation(scorable))
        insights.append(contentsOf: horizonCorrelation(scorable))
        insights.append(contentsOf: highConfidenceWarning(scorable))
        insights.append(contentsOf: dayOfWeekCorrelation(scorable))
        insights.append(contentsOf: streakCorrelation(scorable))

        return insights.sorted { lhs, rhs in
            strengthRank(lhs.strength) > strengthRank(rhs.strength)
        }
    }

    private static func strengthRank(_ s: Insight.Strength) -> Int {
        switch s { case .strong: 3; case .moderate: 2; case .weak: 1 }
    }

    // MARK: - Time of day

    private static func timeOfDayCorrelation(_ predictions: [Prediction]) -> [Insight] {
        let morning = predictions.filter { hour(of: $0.createdAt) < 12 }
        let evening = predictions.filter { hour(of: $0.createdAt) >= 18 }
        guard morning.count >= 5, evening.count >= 5 else { return [] }

        guard let mBrier = ScoringEngine.aggregateBrier(morning),
              let eBrier = ScoringEngine.aggregateBrier(evening) else { return [] }

        let diff = abs(mBrier - eBrier)
        guard diff > 0.02 else { return [] }

        let worseHalf = mBrier > eBrier ? "morning" : "evening"
        let pts = Int((diff * 100).rounded())
        return [Insight(
            headline: "You're more overconfident in the \(worseHalf)",
            detail: "Predictions made in the \(worseHalf) score \(pts) Brier-points worse than your other half-day. Consider adding a 15-minute pause before high-confidence morning predictions.",
            strength: diff > 0.05 ? .strong : (diff > 0.03 ? .moderate : .weak),
            kind: .overconfidence
        )]
    }

    // MARK: - Mood

    private static func moodCorrelation(_ predictions: [Prediction]) -> [Insight] {
        let withMood = predictions.filter { $0.moodTag != nil }
        guard withMood.count >= 8 else { return [] }

        let lowMood = withMood.filter { ($0.moodTag?.level ?? 3) <= 2 }
        let highMood = withMood.filter { ($0.moodTag?.level ?? 3) >= 4 }
        guard lowMood.count >= 3, highMood.count >= 3 else { return [] }

        guard let lBrier = ScoringEngine.aggregateBrier(lowMood),
              let hBrier = ScoringEngine.aggregateBrier(highMood) else { return [] }

        let diff = abs(lBrier - hBrier)
        guard diff > 0.03 else { return [] }

        let worseMood = lBrier > hBrier ? "low" : "high"
        let pts = Int((diff * 100).rounded())
        return [Insight(
            headline: "Your calibration drops when mood is \(worseMood)",
            detail: "When you're in a \(worseMood) mood, your predictions score \(pts) Brier-points worse than when mood is \(worseMood == "low" ? "high" : "low").",
            strength: diff > 0.06 ? .strong : .moderate,
            kind: .pattern
        )]
    }

    // MARK: - Category bias

    private static func categoryCorrelation(_ predictions: [Prediction]) -> [Insight] {
        let byCategory = Dictionary(grouping: predictions) { $0.category }
        var worst: (PredictionCategory, Double)? = nil
        var best: (PredictionCategory, Double)? = nil

        for (cat, group) in byCategory where group.count >= 4 {
            guard let b = ScoringEngine.aggregateBrier(group) else { continue }
            if worst == nil || b > worst!.1 { worst = (cat, b) }
            if best == nil || b < best!.1 { best = (cat, b) }
        }

        guard let w = worst, let bb = best, w.0 != bb.0 else { return [] }
        let diff = w.1 - bb.1
        guard diff > 0.05 else { return [] }

        return [Insight(
            headline: "You're sharpest on \(bb.0.displayName)",
            detail: "Your \(bb.0.displayName.lowercased()) predictions score \(PariFormat.brier(bb.1)) — your \(w.0.displayName.lowercased()) predictions score \(PariFormat.brier(w.1)). Consider lowering confidence on \(w.0.displayName.lowercased()) by 5–10 points.",
            strength: diff > 0.10 ? .strong : .moderate,
            kind: .overconfidence
        )]
    }

    // MARK: - Horizon

    private static func horizonCorrelation(_ predictions: [Prediction]) -> [Insight] {
        let short = predictions.filter { $0.horizon == .days || $0.horizon == .weeks }
        let long = predictions.filter { $0.horizon == .months || $0.horizon == .long }
        guard short.count >= 5, long.count >= 5 else { return [] }

        guard let sBrier = ScoringEngine.aggregateBrier(short),
              let lBrier = ScoringEngine.aggregateBrier(long) else { return [] }

        let diff = abs(sBrier - lBrier)
        guard diff > 0.03 else { return [] }

        let worse = sBrier > lBrier ? "short-term" : "long-term"
        let pts = Int((diff * 100).rounded())
        return [Insight(
            headline: "\(worse.capitalized) predictions hurt you most",
            detail: "Your \(worse) predictions score \(pts) Brier-points worse than the other horizon. \(sBrier > lBrier ? "Short-term overconfidence is the most common pattern." : "Long-term humility is unusual — well done.")",
            strength: diff > 0.06 ? .strong : .moderate,
            kind: .pattern
        )]
    }

    // MARK: - High-confidence pitfall

    private static func highConfidenceWarning(_ predictions: [Prediction]) -> [Insight] {
        let high = predictions.filter { $0.confidencePercent >= 90 }
        guard high.count >= 5 else { return [] }

        let hits = high.filter { $0.outcome == .yes }.count
        let hitRate = Double(hits) / Double(high.count)
        let avgConf = Double(high.reduce(0) { $0 + $1.confidencePercent }) / Double(high.count) / 100.0
        let gap = avgConf - hitRate

        guard gap > 0.10 else { return [] }
        let pct = Int((gap * 100).rounded())
        return [Insight(
            headline: "Your 90%+ predictions are a trap",
            detail: "When you said 90%+, reality agreed only \(Int(hitRate * 100))% of the time — a \(pct)-point overconfidence gap. Treat 90% as your danger zone.",
            strength: gap > 0.20 ? .strong : .moderate,
            kind: .overconfidence
        )]
    }

    // MARK: - Day of week

    private static func dayOfWeekCorrelation(_ predictions: [Prediction]) -> [Insight] {
        let cal = Calendar.current
        var weekday: [Prediction] = []
        var weekend: [Prediction] = []
        for p in predictions {
            let w = cal.component(.weekday, from: p.createdAt)
            if w == 1 || w == 7 { weekend.append(p) } else { weekday.append(p) }
        }
        guard weekday.count >= 5, weekend.count >= 3 else { return [] }
        guard let wBrier = ScoringEngine.aggregateBrier(weekday),
              let eBrier = ScoringEngine.aggregateBrier(weekend) else { return [] }
        let diff = abs(wBrier - eBrier)
        guard diff > 0.04 else { return [] }
        let worse = wBrier > eBrier ? "weekday" : "weekend"
        let pts = Int((diff * 100).rounded())
        return [Insight(
            headline: "\(worse.capitalized) predictions slip",
            detail: "You score \(pts) Brier-points worse on predictions made on a \(worse). Could be context (busy schedule, mental fatigue).",
            strength: .moderate,
            kind: .pattern
        )]
    }

    // MARK: - Speed-of-entry signal

    private static func streakCorrelation(_ predictions: [Prediction]) -> [Insight] {
        let withCriteria = predictions.filter { $0.resolutionCriteria.count > 30 }
        let shortCriteria = predictions.filter { $0.resolutionCriteria.count <= 30 }
        guard withCriteria.count >= 4, shortCriteria.count >= 4 else { return [] }
        guard let dBrier = ScoringEngine.aggregateBrier(withCriteria),
              let qBrier = ScoringEngine.aggregateBrier(shortCriteria) else { return [] }
        let diff = qBrier - dBrier
        guard diff > 0.04 else { return [] }
        let pts = Int((diff * 100).rounded())
        return [Insight(
            headline: "Specific criteria pay off",
            detail: "Predictions with detailed criteria (>30 chars) score \(pts) Brier-points better. Slow down at write time — future-you wins.",
            strength: .moderate,
            kind: .accuracy
        )]
    }

    // MARK: - Helpers

    private static func hour(of date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }
}
