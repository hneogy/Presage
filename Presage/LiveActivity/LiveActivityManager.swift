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
}
