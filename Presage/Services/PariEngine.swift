import SwiftUI
import SwiftData
import CoreSpotlight

@Observable
@MainActor
final class PariEngine {
    var showNewPrediction = false
    var showQuickPredict = false
    var resolvingPrediction: Prediction?
    var activeTab: Int = 0
    var pendingDeepLinkPredictionID: UUID?

    private let calibrationCache: CalibrationCache

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    var predictionCount: Int {
        get { UserDefaults.standard.integer(forKey: "predictionCount") }
        set { UserDefaults.standard.set(newValue, forKey: "predictionCount") }
    }

    init(calibrationCache: CalibrationCache) {
        self.calibrationCache = calibrationCache
    }

    func createPrediction(
        claim: String,
        resolutionCriteria: String,
        confidencePercent: Int,
        resolutionDate: Date,
        category: PredictionCategory,
        moodTag: MoodTag?,
        witnessName: String?,
        in context: ModelContext
    ) {
        let quality = QualityChecker.assess(claim: claim, criteria: resolutionCriteria)
        let prediction = Prediction(
            claim: claim,
            resolutionCriteria: resolutionCriteria,
            confidencePercent: confidencePercent,
            resolutionDate: resolutionDate,
            category: category,
            moodTag: moodTag,
            witnessName: witnessName,
            qualityFlag: quality
        )
        context.insert(prediction)
        predictionCount += 1

        Task {
            await NotificationScheduler.shared.scheduleResolutionReminder(for: prediction)
            await SpotlightIndexer.index(prediction)
            LiveActivityManager.startActivity(for: prediction)
        }

        WidgetReloader.reloadAll()
    }

    func resolve(
        _ prediction: Prediction,
        outcome: ResolutionOutcome,
        fudged: Bool,
        in context: ModelContext
    ) {
        prediction.outcome = outcome
        prediction.isFudged = fudged
        prediction.resolvedAt = .now

        // Persist BEFORE recomputing the calibration snapshot. Without
        // an explicit save, autosave timing decides whether the
        // just-resolved row is visible to the recompute. Matters because
        // the reveal phase shows "your overall Brier is now X"
        // immediately after the user answers.
        try? context.save()
        try? calibrationCache.recompute(using: context)

        let resolvedID = prediction.id
        Task {
            await NotificationScheduler.shared.cancelReminder(for: resolvedID)
            await SpotlightIndexer.index(prediction)
            await LiveActivityManager.endActivity(for: resolvedID)
        }

        if #available(iOS 17.0, *) {
            BrierScoreExplanationTip.firstResolutionEvent.sendDonation()
        }

        WidgetReloader.reloadAll()

        // CRITICAL: do NOT clear `resolvingPrediction` here. The flow is
        // presented via `fullScreenCover(item: $engine.resolvingPrediction)`.
        // Clearing the item dismisses the cover, which would happen
        // BEFORE the user sees Phase 2 (the reveal) — silently breaking
        // the signature honesty mechanic. ResolutionFlow's "Done" button
        // calls `dismiss()` explicitly, which clears the cover correctly
        // through the binding's natural dismissal path.
        //
        // (Bug history: this `= nil` was here from Phase 1 and broke
        // the reveal phase for every resolution. Audit pass 11 caught it.)
    }

    /// Deletes a prediction and all its side-effects: pending notifications,
    /// Spotlight index entry, then triggers a recompute + widget reload.
    /// Without this single chokepoint, prior code paths would leak
    /// pending notifications and Spotlight rows for deleted predictions.
    func deletePrediction(_ prediction: Prediction, in context: ModelContext) {
        let predictionID = prediction.id
        context.delete(prediction)
        try? context.save()

        // Recompute calibration since the deleted prediction may have
        // contributed to it.
        try? calibrationCache.recompute(using: context)

        Task {
            await NotificationScheduler.shared.cancelReminder(for: predictionID)
            await SpotlightIndexer.remove(predictionID)
            await LiveActivityManager.endActivity(for: predictionID)
        }

        WidgetReloader.reloadAll()
    }

    /// Edits an unresolved prediction. Resolved predictions are immutable —
    /// editing them would corrupt the calibration history. This guard is
    /// the single place that rule lives.
    func editPrediction(
        _ prediction: Prediction,
        claim: String,
        resolutionCriteria: String,
        confidencePercent: Int,
        resolutionDate: Date,
        in context: ModelContext
    ) -> Bool {
        guard !prediction.isResolved else { return false }

        prediction.claim = claim
        prediction.resolutionCriteria = resolutionCriteria
        prediction.confidencePercent = confidencePercent

        let dateChanged = prediction.resolutionDate != resolutionDate
        prediction.resolutionDate = resolutionDate
        prediction.qualityFlag = QualityChecker.assess(claim: claim, criteria: resolutionCriteria)
        try? context.save()

        // If the resolution date moved, the previously scheduled reminders
        // are now wrong — reschedule.
        if dateChanged {
            Task {
                await NotificationScheduler.shared.cancelReminder(for: prediction.id)
                await NotificationScheduler.shared.scheduleResolutionReminder(for: prediction)
                await SpotlightIndexer.index(prediction)
            }
        } else {
            Task { await SpotlightIndexer.index(prediction) }
        }

        WidgetReloader.reloadAll()
        return true
    }

    /// Erases ALL user data — predictions, calibration snapshot, training
    /// answers, flashcards, templates, AI scoring history, life forecasts,
    /// teams. Used by the "Reset Présage" button in Settings. Side-effects
    /// (notifications, spotlight, widgets) are also cleared.
    func eraseAllData(in context: ModelContext) {
        // 1. Cancel ALL pending notifications (resolution reminders + retention pushes).
        NotificationScheduler.shared.cancelAll()

        // 2. End any lingering lock-screen Live Activities. Without this,
        //    a banner started for a now-deleted prediction would survive
        //    the reset and keep counting down to a resolution date that
        //    no longer corresponds to any record.
        Task { await LiveActivityManager.endActivities() }

        // 3. Clear Spotlight index for all Présage content.
        Task { try? await CSSearchableIndex.default().deleteAllSearchableItems() }

        // 3. Delete every record SwiftData knows about.
        try? context.delete(model: Prediction.self)
        try? context.delete(model: CalibrationSnapshot.self)
        try? context.delete(model: PredictionTemplate.self)
        try? context.delete(model: TrainingQuestion.self)
        try? context.delete(model: FlashCard.self)
        try? context.delete(model: AIPrediction.self)
        try? context.delete(model: DuelPrediction.self)
        try? context.delete(model: CoachMessage.self)
        try? context.delete(model: TeamWorkspace.self)
        try? context.delete(model: TeamPrediction.self)
        try? context.delete(model: LifeForecast.self)
        try? context.save()

        // 4. Reset onboarding + counters so the user gets a fresh first-run.
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(0, forKey: "predictionCount")
        UserDefaults.standard.set(false, forKey: "leaderboardOptedIn")
        UserDefaults.standard.removeObject(forKey: "leaderboardPseudonym")
        UserDefaults.standard.removeObject(forKey: "user-state-code")

        WidgetReloader.reloadAll()
    }

    func handleForeground(context: ModelContext) {
        try? calibrationCache.recomputeIfStale(using: context)
        BackgroundTaskScheduler.schedule()
        WidgetReloader.reloadAll()
    }

    /// Whether some modal (full-screen cover or quick predict sheet) is
    /// currently presented. Deep links that need to present a *different*
    /// modal must dismiss the current one first to avoid SwiftUI's
    /// "cover on cover not allowed" silent failure.
    private var modalIsPresented: Bool {
        showNewPrediction || showQuickPredict || resolvingPrediction != nil
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme == "pari" else { return }

        switch url.host {
        case "resolve":
            // If we're inside another modal (creating a prediction, quick
            // predict, or another resolution), close it first; the
            // pending ID will be picked up by PredictionListView.onAppear
            // once the cover is gone. Without this, the new resolution
            // silently fails to present.
            if modalIsPresented {
                showNewPrediction = false
                showQuickPredict = false
                resolvingPrediction = nil
            }
            if let idString = url.pathComponents.dropFirst().first,
               let uuid = UUID(uuidString: idString) {
                pendingDeepLinkPredictionID = uuid
            }
            activeTab = 1
        case "new":
            // Don't open new-prediction over an existing modal.
            if !modalIsPresented {
                showNewPrediction = true
            }
        case "quick":
            if !modalIsPresented {
                showQuickPredict = true
            }
        case "home":
            activeTab = 0
        case "coach":
            activeTab = 3
        case "insights":
            activeTab = 2
        case "predictions":
            activeTab = 1
        default:
            break
        }
    }

    func handleSpotlight(_ userActivity: NSUserActivity) {
        guard userActivity.activityType == CSSearchableItemActionType,
              let id = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let uuid = UUID(uuidString: id) else { return }
        pendingDeepLinkPredictionID = uuid
        activeTab = 1
    }

    func resolvePending(from predictions: [Prediction]) {
        guard let id = pendingDeepLinkPredictionID,
              let prediction = predictions.first(where: { $0.id == id }) else { return }
        resolvingPrediction = prediction
        pendingDeepLinkPredictionID = nil
    }
}
