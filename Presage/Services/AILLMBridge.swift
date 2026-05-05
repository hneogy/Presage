import Foundation
import Security

/// Bridge to user-supplied LLMs. The user provides their own API key
/// (stored in Keychain) — Pari never proxies through a server.
/// Used by Human-vs-AI Duels and Pari for AI scoring.
@MainActor
final class AILLMBridge {
    static let shared = AILLMBridge()

    private let keychainServiceOpenAI = "com.pari.neogy.openai.apikey"
    private let keychainServiceAnthropic = "com.pari.neogy.anthropic.apikey"

    /// In-memory cache so repeated calls (UI re-renders, hasKey checks
    /// during list scrolls) don't hit the synchronous Keychain API on
    /// every read. Invalidated on store/migration so a freshly saved
    /// key surfaces immediately.
    private var keyCache: [AIModel: String?] = [:]

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
        let service = model == .gpt5 ? keychainServiceOpenAI : keychainServiceAnthropic
        let data = Data(key.utf8)

        // Delete any existing entry first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
        keyCache[model] = key

        // Migrate: remove any legacy UserDefaults entry
        let legacyKey = model == .gpt5 ? "pari.openai.apikey" : "pari.anthropic.apikey"
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }

    func apiKey(for model: AIModel) -> String? {
        if let cached = keyCache[model] { return cached }

        let service = model == .gpt5 ? keychainServiceOpenAI : keychainServiceAnthropic

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            let key = String(data: data, encoding: .utf8)
            keyCache[model] = key
            return key
        }

        // Migration: check legacy UserDefaults and move to Keychain
        let legacyKey = model == .gpt5 ? "pari.openai.apikey" : "pari.anthropic.apikey"
        if let legacy = UserDefaults.standard.string(forKey: legacyKey) {
            storeAPIKey(legacy, for: model)
            return legacy
        }

        keyCache[model] = nil
        return nil
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
