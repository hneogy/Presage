import AppIntents
import SwiftData
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Shortcuts Provider

struct PariShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickPredictIntent(),
            phrases: [
                "Quick predict in \(.applicationName)",
                "Lock in a prediction in \(.applicationName)"
            ],
            shortTitle: "Quick predict",
            systemImageName: "bolt.circle"
        )
        AppShortcut(
            intent: CreatePredictionIntent(),
            phrases: [
                "Make a prediction in \(.applicationName)",
                "New \(.applicationName) prediction",
                "Predict in \(.applicationName)"
            ],
            shortTitle: "New prediction",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: ResolveNextDueIntent(),
            phrases: [
                "Resolve my next \(.applicationName) prediction",
                "Resolve in \(.applicationName)"
            ],
            shortTitle: "Resolve due",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: ViewBrierScoreIntent(),
            phrases: [
                "Show my \(.applicationName) score",
                "What's my \(.applicationName) Brier score"
            ],
            shortTitle: "View score",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
        AppShortcut(
            intent: ResolveAllDueIntent(),
            phrases: [
                "Resolve all due in \(.applicationName)",
                "Show my \(.applicationName) overdue"
            ],
            shortTitle: "Resolve all due",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: CompareBrierIntent(),
            phrases: [
                "Did I improve in \(.applicationName) this month",
                "Compare my \(.applicationName) Brier"
            ],
            shortTitle: "Brier vs last month",
            systemImageName: "arrow.up.arrow.down"
        )
        AppShortcut(
            intent: OpenCoachIntent(),
            phrases: [
                "Ask \(.applicationName) coach",
                "Open my \(.applicationName) retrospective"
            ],
            shortTitle: "Ask coach",
            systemImageName: "sparkles"
        )
    }
}

// MARK: - Quick Predict Intent (1-tap entry)

struct QuickPredictIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Predict"
    static var description = IntentDescription(
        "Lock in a prediction in two taps. Defaults to 70% / 1 week.",
        categoryName: "Predictions"
    )
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = true

    static var parameterSummary: some ParameterSummary {
        Summary("Predict \(\.$claim) in Présage")
    }

    @Parameter(title: "Claim", description: "What do you predict?")
    var claim: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = CloudSyncManager.makeContainer()
        let context = container.mainContext

        let inferred = await ConfidenceExtractor.extract(from: claim) ?? 70
        let resolutionDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

        let prediction = Prediction(
            claim: claim,
            resolutionCriteria: "I'll know it when I see it.",
            confidencePercent: inferred,
            resolutionDate: resolutionDate,
            category: .behavior
        )
        context.insert(prediction)
        try? context.save()
        await NotificationScheduler.shared.scheduleResolutionReminder(for: prediction)

        return .result(dialog: "Locked in at \(inferred)%, resolves in 7 days.")
    }
}

// MARK: - Create Prediction Intent

struct CreatePredictionIntent: AppIntent {
    static var title: LocalizedStringResource = "New Prediction"
    static var description = IntentDescription(
        "Create a new prediction with a confidence percentage and resolution date.",
        categoryName: "Predictions"
    )
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = true

    static var parameterSummary: some ParameterSummary {
        Summary("Predict \(\.$claim) at \(\.$confidence)% confidence in \(\.$daysOut) days") {
            \.$criteria
        }
    }

    @Parameter(title: "Claim", description: "What do you predict?")
    var claim: String

    @Parameter(title: "Confidence", description: "How confident are you (50-99)?",
               default: 70)
    var confidence: Int

    @Parameter(title: "Resolution Criteria",
               description: "What counts as yes?")
    var criteria: String

    @Parameter(title: "Days until resolution",
               description: "How many days from now does this resolve?",
               default: 7)
    var daysOut: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = CloudSyncManager.makeContainer()
        let context = container.mainContext

        let resolutionDate = Calendar.current.date(byAdding: .day, value: daysOut, to: .now) ?? .now
        let snapped = ConfidenceLevel.snap(confidence)
        let quality = QualityChecker.assess(claim: claim, criteria: criteria)

        let prediction = Prediction(
            claim: claim,
            resolutionCriteria: criteria,
            confidencePercent: snapped,
            resolutionDate: resolutionDate,
            category: .behavior,
            qualityFlag: quality
        )
        context.insert(prediction)
        try? context.save()

        await NotificationScheduler.shared.scheduleResolutionReminder(for: prediction)
        await SpotlightIndexer.index(prediction)

        return .result(dialog: "Saved at \(snapped)% confidence, resolves in \(daysOut) days.")
    }
}

// MARK: - Resolve Next Due Intent

struct ResolveNextDueIntent: AppIntent {
    static var title: LocalizedStringResource = "Resolve Next Due Prediction"
    static var description = IntentDescription(
        "Open the next overdue prediction to resolve it.",
        categoryName: "Predictions"
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = CloudSyncManager.makeContainer()
        let context = container.mainContext

        let now = Date.now
        let descriptor = FetchDescriptor<Prediction>(
            predicate: #Predicate { $0.outcomeRaw == nil && $0.resolutionDate <= now },
            sortBy: [SortDescriptor(\.resolutionDate)]
        )
        let due = try context.fetch(descriptor)

        guard let next = due.first else {
            return .result(dialog: "No predictions due right now.")
        }

        if let url = URL(string: "pari://resolve/\(next.id.uuidString)") {
            await UIApplication.shared.open(url)
        }

        return .result(dialog: "Opening: \(next.claim)")
    }
}

// MARK: - View Brier Score Intent

struct ViewBrierScoreIntent: AppIntent {
    static var title: LocalizedStringResource = "View Brier Score"
    static var description = IntentDescription("See your current Brier score.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = CloudSyncManager.makeContainer()
        let context = container.mainContext

        let descriptor = FetchDescriptor<CalibrationSnapshot>(
            sortBy: [SortDescriptor(\.computedAt, order: .reverse)]
        )
        let snapshots = try context.fetch(descriptor)

        guard let brier = snapshots.first?.brierScore else {
            return .result(dialog: "Not enough resolved predictions yet.")
        }

        let formatted = PariFormat.brier(brier)
        return .result(dialog: "Your Brier score is \(formatted) across \(snapshots.first?.totalResolved ?? 0) resolved predictions.")
    }
}

// MARK: - Resolve All Due Intent

struct ResolveAllDueIntent: AppIntent {
    static var title: LocalizedStringResource = "Resolve all due predictions"
    static var description = IntentDescription("Surface all overdue predictions.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = CloudSyncManager.makeContainer()
        let context = container.mainContext
        let now = Date.now
        let descriptor = FetchDescriptor<Prediction>(
            predicate: #Predicate { $0.outcomeRaw == nil && $0.resolutionDate <= now }
        )
        let due = try context.fetch(descriptor)
        return .result(dialog: due.isEmpty
                       ? "Nothing's due. You're caught up."
                       : "\(due.count) prediction\(due.count == 1 ? "" : "s") to resolve.")
    }
}

// MARK: - Compare Brier Intent

struct CompareBrierIntent: AppIntent {
    static var title: LocalizedStringResource = "Compare Brier this month vs last"
    static var description = IntentDescription("See if you've improved or slipped this month.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = CloudSyncManager.makeContainer()
        let context = container.mainContext

        let cal = Calendar.current
        let now = Date.now
        let monthAgo = cal.date(byAdding: .month, value: -1, to: now) ?? now
        let twoMonthsAgo = cal.date(byAdding: .month, value: -2, to: now) ?? now

        let descriptor = FetchDescriptor<Prediction>(
            predicate: #Predicate { $0.resolvedAt != nil }
        )
        let resolved = try context.fetch(descriptor)
        let thisMonth = resolved.filter { ($0.resolvedAt ?? .distantPast) >= monthAgo }
        let lastMonth = resolved.filter { d in
            guard let r = d.resolvedAt else { return false }
            return r >= twoMonthsAgo && r < monthAgo
        }

        guard let cur = ScoringEngine.aggregateBrier(thisMonth),
              let prev = ScoringEngine.aggregateBrier(lastMonth) else {
            return .result(dialog: "Not enough data across both months yet.")
        }

        let direction = cur < prev ? "improved" : "slipped"
        let delta = abs(cur - prev)
        return .result(dialog: "You \(direction) by \(PariFormat.brier(delta)). This month: \(PariFormat.brier(cur)). Last: \(PariFormat.brier(prev)).")
    }
}

// MARK: - Open Coach Intent

struct OpenCoachIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Présage Coach"
    static var description = IntentDescription("Open Présage Coach for a calibration retrospective.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult { .result() }
}
