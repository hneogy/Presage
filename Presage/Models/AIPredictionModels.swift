import Foundation
import SwiftData

// MARK: - AI Hallucination Scoring (the asymmetric bet)

@Model
final class AIPrediction: Identifiable {
    @Attribute(.unique) var id: UUID
    var question: String
    var aiAnswer: String
    var aiModelRaw: String              // gpt-5, claude-4, gemini-2-pro, custom
    var userConfidencePercent: Int      // user's confidence the AI is correct
    var aiSelfReportedConfidence: Int?  // if model reports its own confidence
    var createdAt: Date
    var resolvedAt: Date?
    var actualWasCorrect: Bool?
    var userBrierScore: Double?
    var aiBrierScore: Double?
    var notes: String?

    init(question: String, aiAnswer: String, aiModel: AIModel,
         userConfidence: Int, aiConfidence: Int? = nil) {
        self.id = UUID()
        self.question = question
        self.aiAnswer = aiAnswer
        self.aiModelRaw = aiModel.rawValue
        self.userConfidencePercent = userConfidence
        self.aiSelfReportedConfidence = aiConfidence
        self.createdAt = .now
    }

    var aiModel: AIModel {
        AIModel(rawValue: aiModelRaw) ?? .other
    }
}

enum AIModel: String, Codable, CaseIterable, Sendable {
    case gpt5
    case claude4
    case claude46
    case gemini2pro
    case llama3
    case other

    var displayName: String {
        switch self {
        case .gpt5: "GPT-5"
        case .claude4: "Claude 4"
        case .claude46: "Claude 4.6"
        case .gemini2pro: "Gemini 2 Pro"
        case .llama3: "Llama 3"
        case .other: "Other"
        }
    }
}

// MARK: - Human vs AI Duel

@Model
final class DuelPrediction: Identifiable {
    @Attribute(.unique) var id: UUID
    var predictionID: UUID            // links to a normal Prediction
    var aiModelRaw: String
    var aiConfidencePercent: Int
    var aiReasoning: String?
    var createdAt: Date
    var humanWon: Bool?               // computed at resolution

    init(predictionID: UUID, aiModel: AIModel, aiConfidence: Int, aiReasoning: String? = nil) {
        self.id = UUID()
        self.predictionID = predictionID
        self.aiModelRaw = aiModel.rawValue
        self.aiConfidencePercent = aiConfidence
        self.aiReasoning = aiReasoning
        self.createdAt = .now
    }

    var aiModel: AIModel { AIModel(rawValue: aiModelRaw) ?? .other }
}

// MARK: - Pari Coach (conversation log)

@Model
final class CoachMessage: Identifiable {
    @Attribute(.unique) var id: UUID
    var role: String          // "coach" | "user"
    var content: String
    var createdAt: Date
    var contextRaw: String?   // "weekly", "creation", "resolution", "general"

    init(role: String, content: String, context: String? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = .now
        self.contextRaw = context
    }
}

// MARK: - Pari for Teams

@Model
final class TeamWorkspace: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var ownerName: String
    var membersData: Data?
    var createdAt: Date

    init(name: String, ownerName: String, members: [TeamMember] = []) {
        self.id = UUID()
        self.name = name
        self.ownerName = ownerName
        self.membersData = try? JSONEncoder().encode(members)
        self.createdAt = .now
    }

    var members: [TeamMember] {
        get {
            guard let data = membersData else { return [] }
            return (try? JSONDecoder().decode([TeamMember].self, from: data)) ?? []
        }
        set { membersData = try? JSONEncoder().encode(newValue) }
    }
}

struct TeamMember: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String
    var role: String
    var brierScore: Double?
    var resolutionCount: Int = 0
}

@Model
final class TeamPrediction: Identifiable {
    @Attribute(.unique) var id: UUID
    var workspaceID: UUID
    var claim: String
    var resolutionCriteria: String
    var resolutionDate: Date
    var createdAt: Date
    var resolvedAt: Date?
    var outcomeRaw: String?
    var memberConfidencesData: Data?  // [memberID: confidence]
    var ownerName: String

    init(workspaceID: UUID, claim: String, criteria: String, resolutionDate: Date, ownerName: String) {
        self.id = UUID()
        self.workspaceID = workspaceID
        self.claim = claim
        self.resolutionCriteria = criteria
        self.resolutionDate = resolutionDate
        self.createdAt = .now
        self.ownerName = ownerName
    }

    var memberConfidences: [String: Int] {
        get {
            guard let data = memberConfidencesData else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        }
        set { memberConfidencesData = try? JSONEncoder().encode(newValue) }
    }
}

// MARK: - Life Forecast

@Model
final class LifeForecast: Identifiable {
    @Attribute(.unique) var id: UUID
    var domainRaw: String      // career, health, relationships, finance, growth
    var horizonYears: Int       // 1, 3, 5
    var visionStatement: String
    var milestonesData: Data?
    var createdAt: Date
    var lastReviewedAt: Date?

    init(domain: LifeDomain, horizonYears: Int, vision: String, milestones: [LifeMilestone] = []) {
        self.id = UUID()
        self.domainRaw = domain.rawValue
        self.horizonYears = horizonYears
        self.visionStatement = vision
        self.milestonesData = try? JSONEncoder().encode(milestones)
        self.createdAt = .now
    }

    var domain: LifeDomain { LifeDomain(rawValue: domainRaw) ?? .career }

    var milestones: [LifeMilestone] {
        get {
            guard let data = milestonesData else { return [] }
            return (try? JSONDecoder().decode([LifeMilestone].self, from: data)) ?? []
        }
        set { milestonesData = try? JSONEncoder().encode(newValue) }
    }
}

enum LifeDomain: String, Codable, CaseIterable, Sendable {
    case career, health, relationships, finance, growth

    var displayName: String {
        switch self {
        case .career: "Career"
        case .health: "Health"
        case .relationships: "Relationships"
        case .finance: "Finance"
        case .growth: "Growth"
        }
    }

    var sfSymbol: String {
        switch self {
        case .career: "briefcase.fill"
        case .health: "heart.fill"
        case .relationships: "person.2.fill"
        case .finance: "dollarsign.circle.fill"
        case .growth: "leaf.fill"
        }
    }
}

struct LifeMilestone: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var description: String
    var confidencePercent: Int
    var targetDate: Date
    var resolved: Bool = false
    var actualOutcome: Bool? = nil
}
