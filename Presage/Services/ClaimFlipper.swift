import Foundation

/// Rewrites a claim by toggling its negation. The two halves of a probability
/// pair refer to the same belief — saying "30% I'll succeed" equals
/// "70% I'll fail". Pari only accepts ≥50% predictions, so users who lean
/// toward "no" should flip the claim instead.
enum ClaimFlipper {

    /// Returns a flipped version of the claim, or nil if no transformation
    /// is found. Operates on common English negation patterns.
    static func flip(_ claim: String) -> String? {
        let trimmed = claim.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Try patterns in order — longer/more specific first so we don't
        // accidentally match a substring of a longer pattern.
        for pattern in patterns {
            if let result = pattern.apply(trimmed) {
                return result
            }
        }

        // Fallback: prefix with "I won't" / capitalized inversion if the
        // claim starts with a pronoun + verb pattern we don't recognize.
        if let fallback = simpleFallback(trimmed) {
            return fallback
        }

        return nil
    }

    // MARK: - Patterns

    private struct FlipPattern {
        let from: String
        let to: String
        let caseInsensitive: Bool

        func apply(_ input: String) -> String? {
            let options: String.CompareOptions = caseInsensitive ? [.caseInsensitive] : []
            guard let range = input.range(of: from, options: options) else { return nil }
            // Only match if it's a word boundary (start of string OR
            // preceded by space/punct). Use `index(_:offsetBy:limitedBy:)`
            // so an unexpected grapheme-cluster boundary on emoji-heavy
            // claims can never trap with an out-of-bounds index call.
            let start = range.lowerBound
            if start != input.startIndex,
               let prev = input.index(start, offsetBy: -1, limitedBy: input.startIndex) {
                let before = input[prev]
                guard before.isWhitespace || before.isPunctuation else { return nil }
            }
            return input.replacingCharacters(in: range, with: to)
        }
    }

    private static let patterns: [FlipPattern] = [
        // Contractions — bidirectional negation toggles
        .init(from: "I will not", to: "I will", caseInsensitive: true),
        .init(from: "I won't", to: "I will", caseInsensitive: true),
        .init(from: "I will", to: "I won't", caseInsensitive: true),

        .init(from: "I'm not going to", to: "I'm going to", caseInsensitive: true),
        .init(from: "I am not going to", to: "I am going to", caseInsensitive: true),
        .init(from: "I'm going to", to: "I'm not going to", caseInsensitive: true),
        .init(from: "I am going to", to: "I am not going to", caseInsensitive: true),

        .init(from: "I don't", to: "I do", caseInsensitive: true),
        .init(from: "I do not", to: "I do", caseInsensitive: true),
        .init(from: "I do", to: "I don't", caseInsensitive: true),

        .init(from: "I haven't", to: "I have", caseInsensitive: true),
        .init(from: "I have not", to: "I have", caseInsensitive: true),
        .init(from: "I have", to: "I haven't", caseInsensitive: true),

        .init(from: "I can't", to: "I can", caseInsensitive: true),
        .init(from: "I cannot", to: "I can", caseInsensitive: true),
        .init(from: "I can", to: "I can't", caseInsensitive: true),

        .init(from: "I shouldn't", to: "I should", caseInsensitive: true),
        .init(from: "I should not", to: "I should", caseInsensitive: true),
        .init(from: "I should", to: "I shouldn't", caseInsensitive: true),

        // Third-person singular
        .init(from: "won't", to: "will", caseInsensitive: true),
        .init(from: "will not", to: "will", caseInsensitive: true),
        .init(from: " will ", to: " won't ", caseInsensitive: true),

        .init(from: "doesn't", to: "does", caseInsensitive: true),
        .init(from: "does not", to: "does", caseInsensitive: true),
        .init(from: " does ", to: " doesn't ", caseInsensitive: true),

        .init(from: "isn't", to: "is", caseInsensitive: true),
        .init(from: "is not", to: "is", caseInsensitive: true),
        .init(from: " is ", to: " isn't ", caseInsensitive: true),

        .init(from: "aren't", to: "are", caseInsensitive: true),
        .init(from: "are not", to: "are", caseInsensitive: true),
        .init(from: " are ", to: " aren't ", caseInsensitive: true),
    ]

    // Fallback for unrecognized starts — wrap in "It is not the case that..."
    // is too clinical; instead, prepend "Not:" as a quick visual flip.
    private static func simpleFallback(_ input: String) -> String? {
        if input.lowercased().hasPrefix("not: ") {
            return String(input.dropFirst(5))
        }
        return "Not: " + input
    }
}
