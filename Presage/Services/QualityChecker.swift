import Foundation

enum QualityChecker {

    private static let vaguePatterns = [
        "something", "stuff", "things", "maybe",
        "kind of", "sort of", "probably", "i think",
        "might", "could", "possibly"
    ]

    static func assess(claim: String, criteria: String) -> QualityFlag {
        if claim.count < 10 || criteria.count < 10 {
            return .vague
        }

        let combined = (claim + " " + criteria).lowercased()
        let vagueHits = vaguePatterns.filter { combined.contains($0) }.count
        if vagueHits >= 3 {
            return .vague
        }

        if criteria.trimmingCharacters(in: .whitespacesAndNewlines) == claim.trimmingCharacters(in: .whitespacesAndNewlines) {
            return .vague
        }

        return .wellSpecified
    }
}
