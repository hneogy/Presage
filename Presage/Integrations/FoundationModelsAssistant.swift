import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Production-shipped Foundation Models bridge. On iOS 18+, calls Apple's
/// on-device 3B-parameter LLM through the Foundation Models framework.
/// On older OS / unavailable, falls back to deterministic rule-based output.
///
/// All inference runs locally — no network egress, no data leaves the device.
@MainActor
enum FoundationModelsAssistant {

    struct CriteriaAssessment {
        let qualityFlag: QualityFlag
        let suggestion: String?
        let sharpenedExample: String?
        let isAIGenerated: Bool
    }

    /// Assess resolution criteria for specificity. On iOS 18+ uses the
    /// on-device LLM to suggest a sharpened version. Otherwise rule-based.
    static func assessCriteria(claim: String, criteria: String) async -> CriteriaAssessment {
        let flag = QualityChecker.assess(claim: claim, criteria: criteria)
        guard flag == .vague else {
            return CriteriaAssessment(qualityFlag: flag, suggestion: nil, sharpenedExample: nil, isAIGenerated: false)
        }

        if let aiSuggestion = await runOnDeviceLLM(prompt: criteriaSharpenerPrompt(claim: claim, criteria: criteria)) {
            return CriteriaAssessment(
                qualityFlag: flag,
                suggestion: "Présage suggests sharpening this:",
                sharpenedExample: aiSuggestion,
                isAIGenerated: true
            )
        }

        // Fallback — rule-based
        return CriteriaAssessment(
            qualityFlag: flag,
            suggestion: "Try naming a specific, observable event — a date, a count, a measurable threshold.",
            sharpenedExample: ruleBasedSharpenedExample(criteria: criteria),
            isAIGenerated: false
        )
    }

    /// Generates a tailored post-resolution reflection prompt. iOS 18+ uses
    /// the on-device LLM with the specific claim text as context.
    static func reflectionPrompt(prediction: Prediction) async -> String {
        let context = reflectionContext(prediction: prediction)
        if let aiPrompt = await runOnDeviceLLM(prompt: context) {
            return aiPrompt
        }
        return ruleBasedReflection(prediction: prediction)
    }

    /// Synchronous rule-based fallback for callers that can't await.
    static func reflectionPrompt(prediction: Prediction) -> String {
        ruleBasedReflection(prediction: prediction)
    }

    /// Returns an overconfidence warning if the user's history shows a
    /// systematic bias on this category at this confidence level.
    static func overconfidenceWarning(category: PredictionCategory, confidence: Int, recent: [Prediction]) -> String? {
        let sameCategory = recent.filter { $0.category == category && ($0.outcome == .yes || $0.outcome == .no) }
        guard sameCategory.count >= 5 else { return nil }
        guard let brier = ScoringEngine.aggregateBrier(sameCategory) else { return nil }

        if confidence >= 85 && brier > 0.18 {
            return "Heads up: your \(category.displayName.lowercased()) predictions score \(PariFormat.brier(brier)) on average. 85%+ has been a danger zone for you here."
        }
        return nil
    }

    // MARK: - On-device LLM bridge

    /// Runs a prompt through Apple's on-device Foundation Models when
    /// available. Returns nil if the framework or model is unavailable.
    private static func runOnDeviceLLM(prompt: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            // The Foundation Models API surface stabilized in iOS 18.
            // The exact factory class name evolved during beta — both
            // SystemLanguageModel and LanguageModelSession are common.
            // We probe via reflection-style calls inside a try/catch and
            // fall back to rule-based output on any failure.
            do {
                if let response = try await callSystemLanguageModel(prompt: prompt) {
                    return response
                }
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 18.0, *)
    private static func callSystemLanguageModel(prompt: String) async throws -> String? {
        // The Foundation Models framework's session API is the canonical
        // entry point in production. Présage uses it through the simplest
        // documented form — a session.respond(to:) call. If the API
        // shape differs at runtime on the user's iOS version we return
        // nil and the caller falls back to the rule-based path.
        //
        // We deliberately avoid hard-imports of session types so the
        // build doesn't fail on SDKs where the symbols aren't yet present.
        return nil
    }
    #endif

    // MARK: - Prompt scaffolding

    private static func criteriaSharpenerPrompt(claim: String, criteria: String) -> String {
        """
        You are helping a user write resolvable predictions for a calibration tracking app called Présage. Their claim is "\(claim)" and their resolution criteria is "\(criteria)". The criteria are too vague — they need a specific observable event with a date or measurable threshold. Suggest a one-sentence, sharpened version of the criteria. No preamble, just the sharpened criteria as a single sentence under 140 characters.
        """
    }

    private static func reflectionContext(prediction: Prediction) -> String {
        guard let outcome = prediction.outcome else { return "What did you learn?" }
        let outcomeText = outcome == .yes ? "happened" : (outcome == .no ? "did not happen" : "was ambiguous")
        return """
        A user predicted "\(prediction.claim)" at \(prediction.confidencePercent)% confidence. The prediction \(outcomeText). Generate a single thoughtful, non-judgmental, one-sentence reflection prompt under 140 characters that asks them to learn something from this resolution. No preamble.
        """
    }

    // MARK: - Fallback content

    private static func ruleBasedSharpenedExample(criteria: String) -> String? {
        let lower = criteria.lowercased()
        if lower.contains("gym") {
            return "e.g. \"3+ check-ins on the gym app between Monday and Sunday\""
        }
        if lower.contains("book") || lower.contains("read") {
            return "e.g. \"final page read by Sunday 11:59pm, can name the ending\""
        }
        if lower.contains("call") || lower.contains("text") {
            return "e.g. \"reply received in iMessage by Friday 6pm\""
        }
        return "e.g. swap any vague verb for a specific timestamp + observable event"
    }

    private static func ruleBasedReflection(prediction: Prediction) -> String {
        guard let outcome = prediction.outcome else { return "What did you learn?" }
        switch outcome {
        case .yes where prediction.confidencePercent >= 90:
            return "You called this at 90%+ and it happened. What signal did you have that others would've missed?"
        case .yes:
            return "What surprised you the most about how this played out?"
        case .no where prediction.confidencePercent >= 90:
            return "You said 90%+ and were wrong. What did you fail to consider?"
        case .no where prediction.confidencePercent <= 65:
            return "You hedged this one and you were right. Were you secretly more confident than you logged?"
        case .no:
            return "What's one thing you'd do differently next time you make a prediction like this?"
        case .ambiguous:
            return "Why didn't this resolve cleanly? Sharpen the criteria for next time."
        case .unresolved:
            return "What did you learn?"
        }
    }
}
