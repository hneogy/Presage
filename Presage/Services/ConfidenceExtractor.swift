import Foundation

/// Reads natural-language hedge words and infers a recommended confidence.
/// "I'm pretty sure I'll go" → 80
/// "I might go to the gym" → 55
/// On iOS 18+ this could route through Foundation Models; today it uses
/// a simple lexicon match. Either way, it's just a *suggestion* — user confirms.
enum ConfidenceExtractor {

    private struct Lexicon {
        let phrase: String
        let recommendedConfidence: Int
    }

    private static let lexicon: [Lexicon] = [
        // 95+ certain
        .init(phrase: "definitely", recommendedConfidence: 95),
        .init(phrase: "for sure", recommendedConfidence: 95),
        .init(phrase: "no question", recommendedConfidence: 95),
        .init(phrase: "100%", recommendedConfidence: 99),
        .init(phrase: "certain", recommendedConfidence: 95),
        .init(phrase: "absolutely", recommendedConfidence: 95),
        // 85-90 high
        .init(phrase: "very likely", recommendedConfidence: 90),
        .init(phrase: "highly likely", recommendedConfidence: 90),
        .init(phrase: "confident", recommendedConfidence: 85),
        .init(phrase: "almost certainly", recommendedConfidence: 90),
        .init(phrase: "i'm sure", recommendedConfidence: 85),
        // 70-80 medium-high
        .init(phrase: "pretty sure", recommendedConfidence: 80),
        .init(phrase: "likely", recommendedConfidence: 75),
        .init(phrase: "i think", recommendedConfidence: 70),
        .init(phrase: "i believe", recommendedConfidence: 70),
        .init(phrase: "probably", recommendedConfidence: 75),
        // 55-65 lean
        .init(phrase: "might", recommendedConfidence: 55),
        .init(phrase: "maybe", recommendedConfidence: 55),
        .init(phrase: "could", recommendedConfidence: 55),
        .init(phrase: "perhaps", recommendedConfidence: 55),
        .init(phrase: "lean", recommendedConfidence: 60),
        .init(phrase: "more likely than not", recommendedConfidence: 65),
        // 50 toss-up
        .init(phrase: "coin flip", recommendedConfidence: 50),
        .init(phrase: "fifty-fifty", recommendedConfidence: 50),
    ]

    /// Returns nil if no signal found. Returns a snapped confidence value otherwise.
    static func extract(from text: String) async -> Int? {
        guard text.count >= 8 else { return nil }
        let lower = text.lowercased()

        var best: Int? = nil
        var bestPhraseLength = 0
        for entry in lexicon where lower.contains(entry.phrase) {
            if entry.phrase.count > bestPhraseLength {
                best = entry.recommendedConfidence
                bestPhraseLength = entry.phrase.count
            }
        }
        guard let value = best else { return nil }
        return ConfidenceLevel.snap(value)
    }
}
