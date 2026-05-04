import Foundation
import SwiftData

@Model
final class Prediction: Identifiable {
    @Attribute(.unique) var id: UUID
    var claim: String
    var resolutionCriteria: String
    var confidencePercent: Int
    var resolutionDate: Date
    var createdAt: Date
    var categoryRaw: String
    var moodTagRaw: String?
    var witnessName: String?
    var witnessContact: String?
    var outcomeRaw: String?
    var qualityFlagRaw: String
    var isFudged: Bool
    var resolvedAt: Date?

    // === New competitive fields ===

    // Question type — yes/no by default, but can be numeric or multiple choice
    var questionTypeRaw: String

    // For numeric / range predictions: low estimate, high estimate, and resolved actual
    var numericLow: Double?
    var numericHigh: Double?
    var numericActual: Double?
    var numericUnit: String?            // "lbs", "books", "$", etc.

    // For multiple-choice predictions: encoded as JSON [{label, confidence}]
    var choicesData: Data?
    var resolvedChoiceLabel: String?

    // Foresee-style optional context fields
    var reasoning: String?              // "the why" — arguments behind the prediction
    var risks: String?                  // what could derail this
    var postResolutionNotes: String?    // written reflection after resolution

    // Free-form tags (in addition to the fixed category)
    var tagsData: Data?

    // Recurrence: predictions can spawn from a template
    var templateID: UUID?               // points to a PredictionTemplate

    // Training-mode flag — these don't count toward real calibration
    var isTrainingMode: Bool

    init(
        claim: String,
        resolutionCriteria: String,
        confidencePercent: Int,
        resolutionDate: Date,
        category: PredictionCategory,
        moodTag: MoodTag? = nil,
        witnessName: String? = nil,
        witnessContact: String? = nil,
        qualityFlag: QualityFlag = .wellSpecified,
        questionType: QuestionType = .yesNo,
        numericLow: Double? = nil,
        numericHigh: Double? = nil,
        numericUnit: String? = nil,
        choices: [PredictionChoice]? = nil,
        reasoning: String? = nil,
        risks: String? = nil,
        tags: [String] = [],
        templateID: UUID? = nil,
        isTrainingMode: Bool = false
    ) {
        self.id = UUID()
        self.claim = claim
        self.resolutionCriteria = resolutionCriteria
        self.confidencePercent = confidencePercent
        self.resolutionDate = resolutionDate
        self.createdAt = .now
        self.categoryRaw = category.rawValue
        self.moodTagRaw = moodTag?.rawValue
        self.witnessName = witnessName
        self.witnessContact = witnessContact
        self.outcomeRaw = nil
        self.qualityFlagRaw = qualityFlag.rawValue
        self.isFudged = false
        self.resolvedAt = nil

        self.questionTypeRaw = questionType.rawValue
        self.numericLow = numericLow
        self.numericHigh = numericHigh
        self.numericActual = nil
        self.numericUnit = numericUnit
        if let choices {
            self.choicesData = try? JSONEncoder().encode(choices)
        }
        self.resolvedChoiceLabel = nil
        self.reasoning = reasoning
        self.risks = risks
        self.postResolutionNotes = nil
        self.tagsData = (try? JSONEncoder().encode(tags))
        self.templateID = templateID
        self.isTrainingMode = isTrainingMode
    }

    // MARK: - Computed

    var category: PredictionCategory {
        get { PredictionCategory(rawValue: categoryRaw) ?? .external }
        set { categoryRaw = newValue.rawValue }
    }

    var outcome: ResolutionOutcome? {
        get { outcomeRaw.flatMap { ResolutionOutcome(rawValue: $0) } }
        set { outcomeRaw = newValue?.rawValue }
    }

    var qualityFlag: QualityFlag {
        get { QualityFlag(rawValue: qualityFlagRaw) ?? .wellSpecified }
        set { qualityFlagRaw = newValue.rawValue }
    }

    var moodTag: MoodTag? {
        get { moodTagRaw.flatMap { MoodTag(rawValue: $0) } }
        set { moodTagRaw = newValue?.rawValue }
    }

    var questionType: QuestionType {
        get { QuestionType(rawValue: questionTypeRaw) ?? .yesNo }
        set { questionTypeRaw = newValue.rawValue }
    }

    var choices: [PredictionChoice] {
        get {
            guard let data = choicesData else { return [] }
            return (try? JSONDecoder().decode([PredictionChoice].self, from: data)) ?? []
        }
        set { choicesData = try? JSONEncoder().encode(newValue) }
    }

    var tags: [String] {
        get {
            guard let data = tagsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set { tagsData = try? JSONEncoder().encode(newValue) }
    }

    var isDue: Bool {
        resolutionDate <= .now && outcomeRaw == nil
    }

    var isResolved: Bool {
        outcomeRaw != nil
    }

    var horizon: HorizonLabel {
        HorizonLabel.from(created: createdAt, resolution: resolutionDate)
    }

    var daysUntilResolution: Int {
        max(0, Calendar.current.dateComponents([.day], from: .now, to: resolutionDate).day ?? 0)
    }

    var daysOverdue: Int {
        guard isDue else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: resolutionDate, to: .now).day ?? 0)
    }
}
