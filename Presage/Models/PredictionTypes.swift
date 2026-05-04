import Foundation
import SwiftData

// MARK: - Prediction Template (recurrence)

@Model
final class PredictionTemplate: Identifiable {
    @Attribute(.unique) var id: UUID
    var claim: String
    var resolutionCriteria: String
    var defaultConfidencePercent: Int
    var categoryRaw: String
    var recurrenceRaw: String
    var startDate: Date
    var horizonDays: Int   // how many days from auto-create to resolution
    var lastSpawnedAt: Date?
    var isActive: Bool

    init(
        claim: String,
        resolutionCriteria: String,
        defaultConfidencePercent: Int,
        category: PredictionCategory,
        recurrence: RecurrencePattern,
        horizonDays: Int = 7
    ) {
        self.id = UUID()
        self.claim = claim
        self.resolutionCriteria = resolutionCriteria
        self.defaultConfidencePercent = defaultConfidencePercent
        self.categoryRaw = category.rawValue
        self.recurrenceRaw = recurrence.rawValue
        self.startDate = .now
        self.horizonDays = horizonDays
        self.lastSpawnedAt = nil
        self.isActive = true
    }

    var category: PredictionCategory {
        get { PredictionCategory(rawValue: categoryRaw) ?? .behavior }
        set { categoryRaw = newValue.rawValue }
    }

    var recurrence: RecurrencePattern {
        get { RecurrencePattern(rawValue: recurrenceRaw) ?? .weekly }
        set { recurrenceRaw = newValue.rawValue }
    }
}

enum RecurrencePattern: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly
    case biweekly
    case monthly

    var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Monthly"
        }
    }

    var intervalDays: Int {
        switch self {
        case .daily: 1
        case .weekly: 7
        case .biweekly: 14
        case .monthly: 30
        }
    }
}

// MARK: - Knowledge / training question

@Model
final class TrainingQuestion: Identifiable {
    @Attribute(.unique) var id: UUID
    var prompt: String
    var correctAnswer: String          // textual correct answer for binary, or numeric truth
    var isYesAnswer: Bool              // for yes/no questions
    var topicRaw: String
    var difficultyRaw: String
    var sourceCitation: String?

    // User's attempt
    var userConfidencePercent: Int?
    var userAnsweredAt: Date?
    var userAnswerYes: Bool?
    var userBrierScore: Double?

    init(
        prompt: String,
        correctAnswer: String,
        isYesAnswer: Bool,
        topic: TrainingTopic,
        difficulty: TrainingDifficulty = .medium,
        sourceCitation: String? = nil
    ) {
        self.id = UUID()
        self.prompt = prompt
        self.correctAnswer = correctAnswer
        self.isYesAnswer = isYesAnswer
        self.topicRaw = topic.rawValue
        self.difficultyRaw = difficulty.rawValue
        self.sourceCitation = sourceCitation
    }

    var topic: TrainingTopic {
        TrainingTopic(rawValue: topicRaw) ?? .general
    }

    var difficulty: TrainingDifficulty {
        TrainingDifficulty(rawValue: difficultyRaw) ?? .medium
    }

    var hasBeenAnswered: Bool { userAnsweredAt != nil }
}

enum TrainingTopic: String, Codable, CaseIterable, Sendable {
    case general
    case history
    case geography
    case science
    case sports
    case currentEvents

    var displayName: String {
        switch self {
        case .general: "General"
        case .history: "History"
        case .geography: "Geography"
        case .science: "Science"
        case .sports: "Sports"
        case .currentEvents: "Current Events"
        }
    }
}

enum TrainingDifficulty: String, Codable, CaseIterable, Sendable {
    case easy, medium, hard
}

// MARK: - Anki-with-uncertainty card

@Model
final class FlashCard: Identifiable {
    @Attribute(.unique) var id: UUID
    var front: String
    var back: String
    var deckName: String
    var createdAt: Date
    var reviewCount: Int
    var lastConfidencePercent: Int?
    var lastWasCorrect: Bool?
    var lastReviewedAt: Date?
    var averageBrierScore: Double?

    init(front: String, back: String, deckName: String = "Default") {
        self.id = UUID()
        self.front = front
        self.back = back
        self.deckName = deckName
        self.createdAt = .now
        self.reviewCount = 0
    }
}
