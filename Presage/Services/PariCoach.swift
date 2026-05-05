import Foundation
import SwiftData

/// On-device LLM coaching agent. Uses Apple Foundation Models when
/// available, falls back to deterministic rule-based responses otherwise.
/// Generates Sunday retrospectives, prediction-time questions, and
/// post-resolution reflection prompts.
///
/// **Read-only contract:** PariCoach must never mutate the
/// ModelContext. It composes strings from snapshot data passed in by
/// the caller; persistence (e.g. recording a `CoachMessage` from the
/// generated string) is the caller's responsibility. Adding writes
/// here would break the assumption every call site makes — that
/// reading from the coach is a free, side-effect-free string lookup.
@MainActor
enum PariCoach {

    enum CoachContext: String {
        case weeklyRetro = "weekly"
        case predictionCreation = "creation"
        case resolution = "resolution"
        case general = "general"
    }

    /// Sunday retrospective: a synthesis message reviewing the week.
    static func weeklyRetrospective(predictions: [Prediction], snapshot: CalibrationSnapshot?) -> String {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: .now) ?? .now
        let thisWeek = predictions.filter {
            ($0.resolvedAt ?? .distantPast) >= weekAgo
        }
        let resolvedCount = thisWeek.filter { $0.outcome == .yes || $0.outcome == .no }.count

        if resolvedCount == 0 {
            return "Nothing resolved this week. That's fine — patient predictions are the best ones. Anything you want to lock in for next week?"
        }

        let weekBrier = ScoringEngine.aggregateBrier(thisWeek)
        let overall = snapshot?.brierScore

        var lines: [String] = []
        lines.append("This week: \(resolvedCount) resolved.")

        if let weekBrier {
            lines.append("Brier this week: \(PariFormat.brier(weekBrier)).")
            if let overall, abs(weekBrier - overall) > 0.02 {
                let direction = weekBrier < overall ? "sharper" : "softer"
                lines.append("That's \(direction) than your overall \(PariFormat.brier(overall)).")
            }
        }

        // Find a notable moment
        let highMisses = thisWeek.filter { $0.outcome == .no && $0.confidencePercent >= 85 }
        if let miss = highMisses.first {
            lines.append("Your most expensive miss: \"\(miss.claim)\" at \(miss.confidencePercent)%.")
            lines.append("What's one thing you should have considered?")
        } else {
            let goodCalls = thisWeek.filter { $0.outcome == .yes && $0.confidencePercent >= 80 }
            if let call = goodCalls.first {
                lines.append("Best call: \"\(call.claim)\" at \(call.confidencePercent)%.")
            }
        }

        return lines.joined(separator: " ")
    }

    /// Pre-creation Socratic question — surfaces evidence the user might be ignoring.
    static func creationPrompt(claim: String, confidence: Int, recentSameCategory: [Prediction]) -> String? {
        guard confidence >= 85 else { return nil }
        let scorable = recentSameCategory.filter { $0.outcome == .yes || $0.outcome == .no }
        guard scorable.count >= 5,
              let brier = ScoringEngine.aggregateBrier(scorable),
              brier > 0.18 else { return nil }
        return "You're at \(confidence)% on this. Your last \(scorable.count) predictions in this category averaged \(PariFormat.brier(brier)) Brier — what evidence would change your mind right now?"
    }

    /// Post-resolution reflection prompt — tailored to outcome and confidence.
    static func reflectionPrompt(prediction: Prediction) -> String {
        FoundationModelsAssistant.reflectionPrompt(prediction: prediction)
    }

    /// Greeting based on time of day and recent activity.
    static func greeting(activeCount: Int, dueCount: Int) -> String {
        let hour = Calendar.current.component(.hour, from: .now)
        let timeBlock: String
        if hour < 12 { timeBlock = "Morning" }
        else if hour < 18 { timeBlock = "Afternoon" }
        else { timeBlock = "Evening" }

        if dueCount > 0 {
            return "\(timeBlock). You have \(dueCount) prediction\(dueCount == 1 ? "" : "s") to resolve."
        }
        return "\(timeBlock). \(activeCount) prediction\(activeCount == 1 ? "" : "s") in flight."
    }
}
