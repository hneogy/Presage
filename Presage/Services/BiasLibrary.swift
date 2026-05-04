import Foundation

/// Encyclopedia of cognitive biases. When the Correlation Engine detects
/// a pattern, it links to the matching bias here so users learn the named
/// concept rather than just seeing a stat.
enum BiasLibrary {

    struct Bias: Identifiable, Hashable {
        var id: String
        let name: String
        let oneLiner: String
        let plainEnglish: String
        let researchCitation: String
        let triggers: [Trigger]

        enum Trigger: String, Hashable {
            case overconfidence
            case underconfidence
            case morningBias
            case lowMoodBias
            case categoryGap
            case shortHorizonBias
            case longHorizonBias
            case highConfidenceTrap
            case planningFallacy
            case vagueCriteria
        }
    }

    static let all: [Bias] = [
        Bias(
            id: "dunning-kruger",
            name: "Dunning–Kruger effect",
            oneLiner: "When you don't know enough to know what you don't know.",
            plainEnglish: "Low-skill people often rate themselves as more skilled than they are. The trap: confidence rises before competence does. If your 90%+ predictions miss often, you're hitting the cliff.",
            researchCitation: "Kruger & Dunning (1999), \"Unskilled and Unaware of It\"",
            triggers: [.highConfidenceTrap, .overconfidence]
        ),
        Bias(
            id: "planning-fallacy",
            name: "Planning fallacy",
            oneLiner: "We always think it'll take less time than it does.",
            plainEnglish: "People consistently underestimate how long their own tasks will take, even when they remember being wrong before. Short-horizon predictions about 'I'll finish by X' are the canonical case.",
            researchCitation: "Kahneman & Tversky (1979)",
            triggers: [.shortHorizonBias, .overconfidence, .planningFallacy]
        ),
        Bias(
            id: "optimism-bias",
            name: "Optimism bias",
            oneLiner: "You think bad things happen to other people, not you.",
            plainEnglish: "Personal predictions about behavior (gym attendance, work shipped, follow-throughs) systematically skew optimistic. The fix: predict for 'a friend like me' rather than yourself.",
            researchCitation: "Sharot (2011), \"The Optimism Bias\"",
            triggers: [.overconfidence, .categoryGap]
        ),
        Bias(
            id: "mood-congruence",
            name: "Mood-congruent judgment",
            oneLiner: "Bad mood, gloomy predictions; good mood, rosy predictions.",
            plainEnglish: "Your current emotional state tilts probability assessments. Predictions made when tired or upset systematically miss in one direction.",
            researchCitation: "Bower (1981), \"Mood and Memory\"",
            triggers: [.lowMoodBias]
        ),
        Bias(
            id: "morning-confidence",
            name: "Hot-cold empathy gap",
            oneLiner: "Future-you is going to be tired and busy. Present-you forgets.",
            plainEnglish: "When you're rested and clear-headed (mornings, coffee in hand), you over-predict what your tired afternoon-self will accomplish. Future-you doesn't have your current energy.",
            researchCitation: "Loewenstein (2005)",
            triggers: [.morningBias, .overconfidence]
        ),
        Bias(
            id: "overconfidence-effect",
            name: "Overconfidence effect",
            oneLiner: "We're more sure than we should be.",
            plainEnglish: "Across virtually every domain studied, people's stated confidence exceeds their accuracy. The gap is largest at the high end — 'I'm 99% sure' is correct ~85% of the time on average.",
            researchCitation: "Lichtenstein, Fischhoff, Phillips (1982)",
            triggers: [.highConfidenceTrap, .overconfidence]
        ),
        Bias(
            id: "horizon-fog",
            name: "Temporal discounting / horizon fog",
            oneLiner: "Long futures look more uniform than they are.",
            plainEnglish: "When you look 6 months out, the world looks fuzzy and you become humble. When you look 3 days out, false specificity creeps in. Calibration on short horizons is often worse for this reason.",
            researchCitation: "Kahneman, Slovic, Tversky (1982)",
            triggers: [.shortHorizonBias]
        ),
        Bias(
            id: "vague-prediction",
            name: "Hedge inflation",
            oneLiner: "Vague claims protect ego, not learning.",
            plainEnglish: "Predictions written quickly with imprecise criteria are easier to retroactively reinterpret as 'basically right.' This isn't a cognitive bias per se — it's motivated criteria-writing. Présage catches it via the criteria-detail correlation.",
            researchCitation: "Tetlock (2005), \"Expert Political Judgment\"",
            triggers: [.vagueCriteria]
        ),
        Bias(
            id: "self-serving",
            name: "Self-serving attribution",
            oneLiner: "Wins are skill, losses are luck.",
            plainEnglish: "When predictions resolve in your favor, you remember them as your insight; when they don't, you blame the situation. Présage fights this with resolve-before-reveal — but if you fudge often, this is the bias.",
            researchCitation: "Miller & Ross (1975)",
            triggers: [.categoryGap]
        ),
        Bias(
            id: "anchoring",
            name: "Anchoring bias",
            oneLiner: "First number sticks; everything else adjusts from it.",
            plainEnglish: "If you saw a confidence number before deciding, your final answer would skew toward it. This is why Présage hides the original confidence at resolution time — preventing you from anchoring on your own past bet.",
            researchCitation: "Tversky & Kahneman (1974)",
            triggers: []
        ),
    ]

    static func biases(for trigger: Bias.Trigger) -> [Bias] {
        all.filter { $0.triggers.contains(trigger) }
    }

    static func bias(byID id: String) -> Bias? {
        all.first { $0.id == id }
    }
}
