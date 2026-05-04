import Foundation

/// Curated list of public-market questions sourced from Kalshi/Metaculus
/// shapes — used as inspiration. User can mirror any of them as a personal
/// prediction with their own confidence.
///
/// Privacy: this is a static bundled list, no network requests, no tracking.
/// In a future build, an opt-in remote-config refresh could update it weekly.
enum PublicMarketBrowser {

    struct PublicQuestion: Identifiable, Hashable {
        var id: String
        let claim: String
        let suggestedCriteria: String
        let resolutionDate: Date
        let category: PredictionCategory
        let source: Source

        enum Source: String { case metaculus = "Metaculus", kalshi = "Kalshi", goodJudgment = "GJ Open" }
    }

    static var curated: [PublicQuestion] {
        let cal = Calendar.current
        let now = Date.now
        func daysOut(_ days: Int) -> Date {
            cal.date(byAdding: .day, value: days, to: now) ?? now
        }

        return [
            PublicQuestion(
                id: "metaculus-ai-2027",
                claim: "Will a frontier AI lab release a model exceeding 10T parameters by end of 2027?",
                suggestedCriteria: "Public release announcement from a major lab (OpenAI, Anthropic, Google, Meta, xAI) confirming ≥10T params.",
                resolutionDate: cal.date(byAdding: .year, value: 2, to: now) ?? now,
                category: .external,
                source: .metaculus
            ),
            PublicQuestion(
                id: "kalshi-fed-rate",
                claim: "Will the Fed cut rates at the next FOMC meeting?",
                suggestedCriteria: "Official FOMC press release announces a target rate decrease ≥25bps.",
                resolutionDate: daysOut(45),
                category: .external,
                source: .kalshi
            ),
            PublicQuestion(
                id: "metaculus-spacex",
                claim: "Will SpaceX complete a successful in-orbit fuel transfer between Starship vehicles in 2026?",
                suggestedCriteria: "SpaceX confirms a successful propellant transfer between two Starships in orbit, before Dec 31 2026.",
                resolutionDate: cal.date(from: DateComponents(year: 2026, month: 12, day: 31)) ?? now,
                category: .external,
                source: .metaculus
            ),
            PublicQuestion(
                id: "kalshi-superbowl",
                claim: "Will the next Super Bowl have over 130M US viewers?",
                suggestedCriteria: "Nielsen reports >130M average US viewers for the next Super Bowl broadcast.",
                resolutionDate: daysOut(120),
                category: .external,
                source: .kalshi
            ),
            PublicQuestion(
                id: "gj-election",
                claim: "Will turnout in the next major US election exceed the prior cycle?",
                suggestedCriteria: "Certified turnout figure from any reputable source (US Elections Project) exceeds the previous cycle by ≥1pt.",
                resolutionDate: daysOut(180),
                category: .external,
                source: .goodJudgment
            ),
            PublicQuestion(
                id: "metaculus-weather",
                claim: "Will a single weather event cause >$100B in US damages this year?",
                suggestedCriteria: "NOAA confirms a single named event resulting in >$100B (inflation-adjusted) damages in this calendar year.",
                resolutionDate: cal.date(byAdding: .month, value: 12, to: now) ?? now,
                category: .external,
                source: .metaculus
            ),
            PublicQuestion(
                id: "kalshi-nba",
                claim: "Will the next NBA Finals MVP be a player born outside the US?",
                suggestedCriteria: "NBA officially announces Finals MVP at end of next Finals; player's birthplace is outside US.",
                resolutionDate: daysOut(90),
                category: .external,
                source: .kalshi
            ),
            PublicQuestion(
                id: "metaculus-temperature",
                claim: "Will the next calendar year set a new global mean surface temperature record?",
                suggestedCriteria: "NASA/NOAA jointly confirm next calendar year as the warmest on record by July following.",
                resolutionDate: cal.date(byAdding: .month, value: 18, to: now) ?? now,
                category: .external,
                source: .metaculus
            ),
        ]
    }
}
