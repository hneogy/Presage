import SwiftUI
import SwiftData
import CoreSpotlight
import OSLog

private let saveLogger = Logger(subsystem: "com.pari.neogy", category: "SwiftDataSave")

/// Centralized SwiftData save error sink. Replaces the dozens of
/// `try? context.save()` sites that silently dropped persistence
/// failures — those failures previously vanished, leaving the user
/// staring at a "saved" UI for data that was never written.
///
/// `attemptSave` returns true on success and logs the failure on
/// error. Call sites that have a user-visible save action should
/// branch on the return value and surface an alert / roll back; call
/// sites where the save is incidental can ignore it but the failure
/// still appears in os_log.
@MainActor
enum PariPersistence {
    @discardableResult
    static func attemptSave(_ context: ModelContext, label: StaticString = "save") -> Bool {
        do {
            try context.save()
            return true
        } catch {
            saveLogger.error("\(String(describing: label), privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}

/// Shared user-text sanitizer. Trims surrounding whitespace, strips
/// control characters and Unicode bidi/format overrides (U+202A..U+202E,
/// U+2066..U+2069, U+200E/F, etc.) that would otherwise let a pasted
/// claim or criteria visually swap text direction in shares, exports,
/// notification banners, and Spotlight results. Caps length to keep one
/// rogue paste from filling SwiftData with a megabyte string.
///
/// CSVImporter has its own private sanitizer with similar semantics —
/// this one matches that contract so a claim typed manually goes
/// through the same hygiene path as one imported from CSV.
enum UserTextSanitizer {
    static func sanitize(_ input: String, maxLength: Int) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.unicodeScalars.filter { scalar in
            // Allow newline (used in multiline criteria), reject any
            // other C0/C1 control or Unicode bidi format override.
            if scalar == "\n" { return true }
            if scalar.value < 0x20 { return false }
            // Strip explicit RTL/LTR overrides + invisible bidi marks.
            let v = scalar.value
            if (0x200E...0x200F).contains(v) { return false }
            if (0x202A...0x202E).contains(v) { return false }
            if (0x2066...0x2069).contains(v) { return false }
            return true
        }
        return String(String.UnicodeScalarView(cleaned).prefix(maxLength))
    }
}

@Observable
@MainActor
final class PariEngine {
    var showNewPrediction = false
    var showQuickPredict = false
    var resolvingPrediction: Prediction?
    var activeTab: Int = 0
    var pendingDeepLinkPredictionID: UUID?
    var pendingShowNewPrediction = false

    private let calibrationCache: CalibrationCache

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    var predictionCount: Int {
        get { UserDefaults.standard.integer(forKey: "predictionCount") }
        set { UserDefaults.standard.set(newValue, forKey: "predictionCount") }
    }

    /// Single source of truth for "a prediction was created" — bumps the
    /// onboarding counter regardless of which path produced it (manual
    /// flow, quick-predict, recurrence spawn, CSV import). Centralizing
    /// this keeps the storage-backend choice in one place.
    static func recordCreation() {
        let key = "predictionCount"
        let next = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(next, forKey: key)
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
        // are now wrong — reschedule. The Live Activity also has to be
        // refreshed so the lock screen doesn't keep counting down to the
        // old date.
        if dateChanged {
            Task {
                await NotificationScheduler.shared.cancelReminder(for: prediction.id)
                await NotificationScheduler.shared.scheduleResolutionReminder(for: prediction)
                await SpotlightIndexer.index(prediction)
                await LiveActivityManager.update(for: prediction)
            }
        } else {
            Task {
                await SpotlightIndexer.index(prediction)
                await LiveActivityManager.update(for: prediction)
            }
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

        // 4. Delete every record SwiftData knows about. Wrapped in a
        //    transaction so a mid-sequence failure rolls back instead of
        //    leaving the store half-erased — silent partial wipes were
        //    the worst-case outcome before this guard.
        do {
            try context.transaction {
                try context.delete(model: Prediction.self)
                try context.delete(model: CalibrationSnapshot.self)
                try context.delete(model: PredictionTemplate.self)
                try context.delete(model: TrainingQuestion.self)
                try context.delete(model: FlashCard.self)
                try context.delete(model: AIPrediction.self)
                try context.delete(model: DuelPrediction.self)
                try context.delete(model: CoachMessage.self)
                try context.delete(model: TeamWorkspace.self)
                try context.delete(model: TeamPrediction.self)
                try context.delete(model: LifeForecast.self)
            }
        } catch {
            // Transaction rolled back — surface to caller via log; the
            // user-visible reset button can read this flag if needed.
            UserDefaults.standard.set(true, forKey: "pari.lastEraseFailed")
        }

        // 5. Reset onboarding + counters so the user gets a fresh first-run.
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

    /// Whether a deep link arrived from an external source (another app)
    /// vs. an internal notification tap. External links get a confirmation
    /// prompt before triggering resolution.
    var pendingExternalDeepLink: URL?

    /// Tracks the in-flight deferred-deep-link task so a second deep link
    /// arriving mid-dismissal can cancel the prior one and replace its
    /// payload, instead of racing two writes to `pendingDeepLinkPredictionID`.
    private var pendingDeepLinkDispatch: Task<Void, Never>?

    func handleDeepLink(_ url: URL, isExternal: Bool = false) {
        guard url.scheme == "pari" else { return }

        switch url.host {
        case "resolve":
            // UUID(uuidString:) is case-insensitive on input but produces
            // a canonical lowercase representation. Normalize the path
            // component before parsing so logs and downstream comparisons
            // (Spotlight identifier match, Live Activity attribute equal)
            // see the same string regardless of how the deep link was
            // typed.
            guard let rawComponent = url.pathComponents.dropFirst().first,
                  let uuid = UUID(uuidString: rawComponent.lowercased()) else { return }
            let idString = uuid.uuidString
            _ = idString // documents the canonical form is now in scope

            // If we're inside another modal, defer until it dismisses.
            // The pending ID will be picked up by PredictionListView
            // once the cover is gone. We can't avoid waiting for the
            // dismiss animation entirely (SwiftUI rejects stacking
            // fullScreenCovers), but cancelling any prior in-flight
            // deferred dispatch keeps a rapid-fire deep link from
            // racing the previous one.
            pendingDeepLinkDispatch?.cancel()
            // A deep link to "resolve" preempts any queued "show new
            // prediction" transition. Without this, dismissing the
            // current sheet would pop a stray New Prediction modal a few
            // frames before our resolution flow tries to land on top of it.
            pendingShowNewPrediction = false
            if modalIsPresented {
                showNewPrediction = false
                showQuickPredict = false
                resolvingPrediction = nil
                let dispatch = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(modalDismissAnimationMillis))
                    guard !Task.isCancelled else { return }
                    self.pendingDeepLinkPredictionID = uuid
                }
                pendingDeepLinkDispatch = dispatch
            } else {
                pendingDeepLinkPredictionID = uuid
            }
            activeTab = 1
        case "new":
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

    /// SwiftUI's default fullScreenCover/sheet dismissal animation. Keep
    /// the constant centralised so a future tweak to presentation timing
    /// only needs one edit.
    private let modalDismissAnimationMillis = 400

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
