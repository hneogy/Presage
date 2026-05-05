import AppIntents
import SwiftData
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Shared post-create helper

@MainActor
private enum IntentPipeline {
    /// Mirrors PariEngine.createPrediction's side-effect chain so that
    /// predictions saved through Shortcuts get the same notification +
    /// Spotlight + Live Activity + counter treatment as predictions made
    /// in-app. We `await` rather than fire-and-forget so the intent
    /// doesn't return success before the work that powers the user's
    /// expectations (resolution reminder!) actually lands.
    static func finishCreate(_ prediction: Prediction) async {
        PariEngine.recordCreation()
        await NotificationScheduler.shared.scheduleResolutionReminder(for: prediction)
        await SpotlightIndexer.index(prediction)
        LiveActivityManager.startActivity(for: prediction)
        WidgetReloader.reloadAll()
    }

    /// Common claim sanitization. Trims whitespace, rejects strings
    /// shorter than 5 chars (the same guard NewPredictionFlow enforces),
    /// and caps at 500 chars to match the CSV importer's ceiling.
    static func sanitize(claim raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5 else {
            throw IntentValidationError.claimTooShort
        }
        return String(trimmed.prefix(500))
    }

    static func sanitize(criteria raw: String?, claim: String, resolutionDate: Date) -> String {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 5 {
            return String(trimmed.prefix(1000))
        }
        // Generate a concrete, criterion-shaped default — same shape the
        // QuickPredict UI uses — so QualityChecker doesn't auto-flag the
        // intent-created prediction as vague.
        return "Did the claim '\(claim)' actually happen by \(resolutionDate.formatted(.dateTime.month(.abbreviated).day()))?"
    }
}

enum IntentValidationError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case claimTooShort

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .claimTooShort:
            return "Claim must be at least 5 characters."
        }
    }
}

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
    /// Writing a prediction from a Shortcut should require the same
    /// trust boundary as opening the app — don't let a lock-screen
    /// automation insert rows into the user's calibration history.
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    static var parameterSummary: some ParameterSummary {
        Summary("Predict \(\.$claim) in Présage")
    }

    @Parameter(title: "Claim", description: "What do you predict?")
    var claim: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = CloudSyncManager.sharedContainer()
        let context = container.mainContext

        let cleanedClaim = try IntentPipeline.sanitize(claim: claim)

        let inferred = await ConfidenceExtractor.extract(from: cleanedClaim) ?? 70
        let resolutionDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        let criteria = IntentPipeline.sanitize(
            criteria: nil,
            claim: cleanedClaim,
            resolutionDate: resolutionDate
        )

        let prediction = Prediction(
            claim: cleanedClaim,
            resolutionCriteria: criteria,
            confidencePercent: inferred,
            resolutionDate: resolutionDate,
            category: .behavior
        )
        context.insert(prediction)
        do {
            try context.save()
        } catch {
            // Roll back so the @Query in the host app doesn't surface a
            // half-saved insert when the intent failed to persist.
            context.delete(prediction)
            return .result(dialog: "Couldn't save: \(error.localizedDescription)")
        }

        await IntentPipeline.finishCreate(prediction)

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
    /// Same lock-screen-write concern as QuickPredictIntent.
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

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
        let container = CloudSyncManager.sharedContainer()
        let context = container.mainContext

        let cleanedClaim = try IntentPipeline.sanitize(claim: claim)
        let clampedDays = max(1, min(3650, daysOut))
        let resolutionDate = Calendar.current.date(byAdding: .day, value: clampedDays, to: .now)
            ?? Date(timeIntervalSinceNow: TimeInterval(clampedDays) * 86400)
        let cleanedCriteria = IntentPipeline.sanitize(
            criteria: criteria,
            claim: cleanedClaim,
            resolutionDate: resolutionDate
        )
        // Clamp to the valid 50-99 ConfidenceLevel domain BEFORE snapping
        // so a Shortcut that passes 0, a negative value, 100, or 200
        // doesn't snap to a meaningless edge bucket. We deliberately
        // floor at 50 (Pari treats sub-50 confidence as a flipped claim
        // and should be expressed by negating the claim, not by passing
        // a low number) and ceil at 99 (100% confidence isn't meaningful
        // — log scoring would explode).
        let bounded: Int = {
            if confidence < 50 { return 50 }
            if confidence > 99 { return 99 }
            return confidence
        }()
        let snapped = ConfidenceLevel.snap(bounded)
        let quality = QualityChecker.assess(claim: cleanedClaim, criteria: cleanedCriteria)

        let prediction = Prediction(
            claim: cleanedClaim,
            resolutionCriteria: cleanedCriteria,
            confidencePercent: snapped,
            resolutionDate: resolutionDate,
            category: .behavior,
            qualityFlag: quality
        )
        context.insert(prediction)
        do {
            try context.save()
        } catch {
            context.delete(prediction)
            return .result(dialog: "Couldn't save: \(error.localizedDescription)")
        }

        await IntentPipeline.finishCreate(prediction)

        return .result(dialog: "Saved at \(snapped)% confidence, resolves in \(clampedDays) days.")
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
    /// Require device unlock before this intent runs. Otherwise a
    /// Shortcut bound to the lock screen could surface (or, with a
    /// future variant, modify) personal predictions without auth.
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = CloudSyncManager.sharedContainer()
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

        // Don't echo the claim into the spoken response — the unlocked
        // user is about to see the resolution UI anyway, and a Siri
        // confirmation that reads sensitive claim text aloud is a
        // privacy footgun.
        return .result(dialog: "Opening your next prediction.")
    }
}

// MARK: - View Brier Score Intent

struct ViewBrierScoreIntent: AppIntent {
    static var title: LocalizedStringResource = "View Brier Score"
    static var description = IntentDescription("See your current Brier score.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = CloudSyncManager.sharedContainer()
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
    /// See ResolveNextDueIntent: same lock-screen exposure concern, same
    /// remediation. Surfaces a count, not claim text — but the count
    /// alone is a privacy signal we'd rather not leak from a locked
    /// device.
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = CloudSyncManager.sharedContainer()
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
        let container = CloudSyncManager.sharedContainer()
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
