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

        // When BOTH a high-certainty phrase ("definitely") and a hedging
        // phrase ("not sure", "might") appear in the same claim, the
        // hedge wins — claims like "I'm not definitely sure" should map
        // to the lean confidence, not the certain one.
        // We pick the matching phrase with the LOWEST recommended
        // confidence so any uncertainty marker overrides certainty.
        var lowestMatch: Int? = nil
        for entry in lexicon where containsAsWord(lower, entry.phrase) {
            if let current = lowestMatch {
                lowestMatch = min(current, entry.recommendedConfidence)
            } else {
                lowestMatch = entry.recommendedConfidence
            }
        }
        guard let value = lowestMatch else { return nil }
        return ConfidenceLevel.snap(value)
    }

    /// True when `phrase` appears in `haystack` flanked by non-letter
    /// boundaries — "I think" matches "i think it's fine" but not
    /// "rethink". Phrases that already contain non-letter characters
    /// (e.g. "100%", "fifty-fifty") fall back to substring containment
    /// since manual word-boundary tokenization breaks down on them.
    private static func containsAsWord(_ haystack: String, _ phrase: String) -> Bool {
        let phraseHasNonLetter = phrase.unicodeScalars.contains { !CharacterSet.letters.contains($0) && $0 != " " }
        if phraseHasNonLetter {
            return haystack.contains(phrase)
        }
        guard let range = haystack.range(of: phrase) else { return false }

        // Check the character before the match (if any) is a boundary.
        if range.lowerBound != haystack.startIndex {
            let prevIdx = haystack.index(before: range.lowerBound)
            if haystack[prevIdx].isLetter { return false }
        }
        // Check the character after.
        if range.upperBound != haystack.endIndex {
            let nextChar = haystack[range.upperBound]
            if nextChar.isLetter { return false }
        }
        return true
    }
}
