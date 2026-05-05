import Foundation

enum QualityChecker {

    private static let vaguePatterns = [
        "something", "stuff", "things", "maybe",
        "kind of", "sort of", "probably", "i think",
        "might", "could", "possibly"
    ]

    static func assess(claim: String, criteria: String) -> QualityFlag {
        // Identity-check FIRST. Even a short claim that's identical to
        // the criteria is unambiguously vague — and reordering this
        // ahead of the length gate means we still flag it for users who
        // happened to make both sides shorter than 10 characters.
        let trimmedClaim = claim.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCriteria = criteria.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedClaim.isEmpty, trimmedClaim.caseInsensitiveCompare(trimmedCriteria) == .orderedSame {
            return .vague
        }

        if claim.count < 10 || criteria.count < 10 {
            return .vague
        }

        let combined = (claim + " " + criteria).lowercased()
        let vagueHits = vaguePatterns.filter { combined.contains($0) }.count
        if vagueHits >= 3 {
            return .vague
        }

        return .wellSpecified
    }
}
