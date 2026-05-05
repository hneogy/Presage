import Foundation

enum PredictionCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case behavior
    case relationships
    case emotion
    case work
    case external

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .behavior: "Behavior"
        case .relationships: "Relationships"
        case .emotion: "Emotion"
        case .work: "Work"
        case .external: "External"
        }
    }

    var sfSymbol: String {
        switch self {
        case .behavior: "figure.run"
        case .relationships: "person.2"
        case .emotion: "heart"
        case .work: "briefcase"
        case .external: "globe"
        }
    }
}

enum ResolutionOutcome: String, Codable, CaseIterable, Sendable {
    case yes
    case no
    case ambiguous
    case unresolved
}

enum QualityFlag: String, Codable, CaseIterable, Sendable {
    case wellSpecified
    case vague
}

enum MoodTag: String, Codable, CaseIterable, Identifiable, Sendable {
    case veryLow
    case low
    case neutral
    case high
    case veryHigh

    var id: String { rawValue }

    var level: Int {
        switch self {
        case .veryLow: 1
        case .low: 2
        case .neutral: 3
        case .high: 4
        case .veryHigh: 5
        }
    }

    var displayName: String {
        switch self {
        case .veryLow: "Very Low"
        case .low: "Low"
        case .neutral: "Neutral"
        case .high: "High"
        case .veryHigh: "Very High"
        }
    }
}

enum HorizonLabel: String, Codable, CaseIterable, Sendable {
    case days = "< 1 week"
    case weeks = "1–4 weeks"
    case months = "1–3 months"
    case long = "3+ months"

    static func from(created: Date, resolution: Date) -> HorizonLabel {
        let dayCount = Calendar.current.dateComponents([.day], from: created, to: resolution).day ?? 0
        switch dayCount {
        case ..<7: return .days
        case ..<28: return .weeks
        case ..<90: return .months
        default: return .long
        }
    }
}

// MARK: - Question type (shared with widget)

enum QuestionType: String, Codable, CaseIterable, Sendable {
    case yesNo
    case numeric
    case multipleChoice

    var displayName: String {
        switch self {
        case .yesNo: "Yes / No"
        case .numeric: "Number / Range"
        case .multipleChoice: "Multiple Choice"
        }
    }

    var sfSymbol: String {
        switch self {
        case .yesNo: "checkmark.circle"
        case .numeric: "number"
        case .multipleChoice: "list.bullet.rectangle"
        }
    }
}

struct PredictionChoice: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var label: String
    var confidencePercent: Int
}

enum ConfidenceLevel {
    static let allSteps: [Int] = [50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 99]
    static let min = 50
    static let max = 99

    /// Round a confidence value to the nearest allowed step. At exact
    /// midpoints (e.g. 52 between 50 and 55, 57 between 55 and 60) we
    /// round UP toward the higher-confidence bucket — without an
    /// explicit tie-breaker, `min(by:)`'s natural behavior with a `<`
    /// strict comparator returned the first equidistant match in
    /// `allSteps`, which is always the lower step. That introduced a
    /// systematic bias toward lower confidence on edge inputs.
    static func snap(_ value: Int) -> Int {
        allSteps.min(by: { lhs, rhs in
            let dl = abs(lhs - value)
            let dr = abs(rhs - value)
            if dl != dr { return dl < dr }
            // Tie: prefer the higher step. lhs > rhs means lhs "wins"
            // the comparator (returned true => lhs is preferred).
            return lhs > rhs
        }) ?? 50
    }

    static func verbalLabel(for confidence: Int) -> String {
        switch confidence {
        case 50...55: "Coin flip"
        case 56...65: "Slight lean"
        case 66...75: "Likely"
        case 76...85: "Confident"
        case 86...94: "Very confident"
        case 95...99: "Near certain"
        default: ""
        }
    }
}
