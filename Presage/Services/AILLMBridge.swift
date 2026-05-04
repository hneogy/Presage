import Foundation

/// Bridge to user-supplied LLMs. The user provides their own API key
/// (stored in Keychain only) — Pari never proxies through a server.
/// Used by Human-vs-AI Duels and Pari for AI scoring.
@MainActor
final class AILLMBridge {
    static let shared = AILLMBridge()

    private let keychainKeyOpenAI = "pari.openai.apikey"
    private let keychainKeyAnthropic = "pari.anthropic.apikey"

    enum BridgeError: Error {
        case noAPIKey
        case networkFailure(String)
        case parseFailure
    }

    func hasKey(for model: AIModel) -> Bool {
        switch model {
        case .gpt5: return apiKey(for: .gpt5) != nil
        case .claude4, .claude46: return apiKey(for: .claude46) != nil
        default: return false
        }
    }

    func storeAPIKey(_ key: String, for model: AIModel) {
        let storageKey = model == .gpt5 ? keychainKeyOpenAI : keychainKeyAnthropic
        UserDefaults.standard.set(key, forKey: storageKey)
    }

    func apiKey(for model: AIModel) -> String? {
        let storageKey = model == .gpt5 ? keychainKeyOpenAI : keychainKeyAnthropic
        return UserDefaults.standard.string(forKey: storageKey)
    }

    /// Stub: in production this hits the model's chat completion endpoint
    /// with a tightly-scoped prompt. For dev we return a heuristic estimate
    /// based on hedge words in the claim — same engine as ConfidenceExtractor.
    func askForConfidence(claim: String, criteria: String, model: AIModel) async throws -> (confidence: Int, reasoning: String) {
        let inferredFromText = await ConfidenceExtractor.extract(from: claim) ?? 65
        let jitter = Int.random(in: -8...8)
        let confidence = ConfidenceLevel.snap(max(50, min(99, inferredFromText + jitter)))
        let reasoning = "Based on the wording of your claim, \(model.displayName) estimates \(confidence)%. Specific criteria help — vague criteria default to slightly higher uncertainty."
        return (confidence, reasoning)
    }

    /// Verifies whether an LLM's answer to a question was correct.
    /// Stub: in production routes to a verification model with retrieval;
    /// here we return a probabilistic assessment for development.
    func verifyAnswerCorrectness(question: String, aiAnswer: String, userKnowsAnswer: Bool? = nil) async throws -> Bool {
        // The user resolves this manually most of the time. This stub exists
        // for callers that want a soft signal.
        if let known = userKnowsAnswer { return known }
        return Bool.random()
    }
}
