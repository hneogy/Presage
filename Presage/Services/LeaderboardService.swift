import Foundation

/// Tier-2 anonymous leaderboard. Strictly opt-in. The only thing that ever
/// leaves the device is a single Brier number + a random pseudonym. No
/// claims, no resolution criteria, no personal data.
///
/// In production this would post to a Cloudflare Worker / D1 table; for
/// now it's a local mock that simulates a global percentile so UI dev
/// can proceed.
@MainActor
@Observable
final class LeaderboardService {
    static let shared = LeaderboardService()

    private let optInKey = "leaderboardOptedIn"
    private let pseudonymKey = "leaderboardPseudonym"

    var isOptedIn: Bool {
        get { UserDefaults.standard.bool(forKey: optInKey) }
        set { UserDefaults.standard.set(newValue, forKey: optInKey) }
    }

    var pseudonym: String {
        if let existing = UserDefaults.standard.string(forKey: pseudonymKey) {
            return existing
        }
        let new = generatePseudonym()
        UserDefaults.standard.set(new, forKey: pseudonymKey)
        return new
    }

    func percentile(for brier: Double) -> Int {
        // Mock distribution centered around 0.18 (typical adult)
        // Returns a percentile 1-99 indicating where the user sits.
        let mean = 0.18
        let stdev = 0.06
        let z = (mean - brier) / stdev   // negative z = worse than mean
        let p = 50.0 + 30.0 * tanh(z)    // bounded 20-80 ish, centered
        return max(1, min(99, Int(p.rounded())))
    }

    func projectedRank(for brier: Double) -> String {
        let p = percentile(for: brier)
        if p >= 95 { return "Top 5%" }
        if p >= 90 { return "Top 10%" }
        if p >= 75 { return "Top 25%" }
        if p >= 50 { return "Top half" }
        return "Bottom half"
    }

    /// Submit anonymous entry. In production this hits a server endpoint;
    /// here it just stores locally to confirm the contract.
    func submit(brier: Double) async {
        guard isOptedIn else { return }
        UserDefaults.standard.set(brier, forKey: "leaderboardLastSubmittedBrier")
        UserDefaults.standard.set(Date.now, forKey: "leaderboardLastSubmittedAt")
    }

    private func generatePseudonym() -> String {
        let adjectives = ["Calm","Quiet","Sharp","Cool","Wide","Open","Long","Plain","Slow","Late","Soft","Even","Dark","Pure"]
        let nouns = ["Otter","Kite","Sparrow","Heron","Wolf","Fox","Crow","Hawk","Lynx","Stag","Owl","Falcon","Bear","Whale"]
        return "\(adjectives.randomElement() ?? "Quiet") \(nouns.randomElement() ?? "Otter")"
    }
}
