import ActivityKit
import Foundation

@MainActor
enum LiveActivityManager {
    static func startActivity(for prediction: Prediction) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attrs = PariActivityAttributes(
            predictionID: prediction.id.uuidString,
            category: prediction.category.displayName
        )
        let state = PariActivityAttributes.ContentState(
            claim: String(prediction.claim.prefix(80)),
            resolutionDate: prediction.resolutionDate,
            hoursOverdue: 0
        )

        let content = ActivityContent(
            state: state,
            staleDate: prediction.resolutionDate.addingTimeInterval(60 * 60 * 24 * 7)
        )

        _ = try? Activity.request(
            attributes: attrs,
            content: content,
            pushType: nil
        )
    }

    static func endActivities() async {
        for activity in Activity<PariActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Ends only the lock-screen activity bound to this prediction. Used
    /// on resolve / delete so the lingering banner doesn't survive the
    /// outcome.
    ///
    /// Bug history: pre-this-pass, resolving a prediction left its Live
    /// Activity on the lock screen forever. The bulk `endActivities()`
    /// existed but was never called, and calling it would have wiped
    /// activities for the user's *other* pending predictions too — so a
    /// per-id ender is the right primitive.
    static func endActivity(for predictionID: UUID) async {
        let id = predictionID.uuidString
        for activity in Activity<PariActivityAttributes>.activities
        where activity.attributes.predictionID == id {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Per-prediction throttle on `update(for:)` calls. ActivityKit
    /// imposes a per-app rate limit (~hourly budget) on Live Activity
    /// content updates; a user editing the same prediction's date in
    /// rapid succession would exhaust the budget and silently drop the
    /// genuinely-final update. We coalesce updates that land within
    /// 750ms of the previous one for the same activity, AND short-
    /// circuit when the new state matches the old one.
    private static var lastUpdateAt: [String: Date] = [:]
    private static var lastSentState: [String: PariActivityAttributes.ContentState] = [:]
    private static let updateCoalesceWindow: TimeInterval = 0.75

    /// Refresh the lock-screen activity for a prediction that the user
    /// edited (claim text, resolution date). Without this, ActivityKit
    /// holds the original `ContentState` until natural expiry, so the
    /// lock screen shows a stale claim or counts down to a date the
    /// prediction no longer has.
    static func update(for prediction: Prediction) async {
        let id = prediction.id.uuidString
        let activities = Activity<PariActivityAttributes>.activities
            .filter { $0.attributes.predictionID == id }
        guard !activities.isEmpty else { return }

        let newState = PariActivityAttributes.ContentState(
            claim: String(prediction.claim.prefix(80)),
            resolutionDate: prediction.resolutionDate,
            hoursOverdue: 0
        )

        // Skip updates whose payload is identical to what we last sent
        // — common when an unrelated edit (e.g. confidence change) calls
        // update() but neither claim nor date actually moved.
        if let last = lastSentState[id],
           last.claim == newState.claim,
           last.resolutionDate == newState.resolutionDate {
            return
        }

        // Coalesce rapid-fire updates: if we sent another update for
        // this prediction within the coalesce window, defer this one
        // briefly so the final-state value wins.
        if let lastAt = lastUpdateAt[id] {
            let elapsed = Date.now.timeIntervalSince(lastAt)
            if elapsed < updateCoalesceWindow {
                let wait = updateCoalesceWindow - elapsed
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
        }

        let staleDate = prediction.resolutionDate.addingTimeInterval(60 * 60 * 24 * 7)
        let content = ActivityContent(state: newState, staleDate: staleDate)

        for activity in activities {
            await activity.update(content)
        }
        lastUpdateAt[id] = .now
        lastSentState[id] = newState
    }
}
