import Foundation
import SwiftData

/// The canonical SwiftData schema, available from any actor isolation.
///
/// Was previously a `static let` on `@MainActor final class CloudSyncManager`
/// — which prevented `PariSharedStore.sharedConfiguration` (a non-isolated
/// helper) from reading it. Lifting the constant to a free-standing enum
/// gives every callsite — main actor, off-main App Intents, the widget
/// extension — the same source of truth without an actor hop.
///
/// Adding a new @Model: register it here. CloudSyncManager.canonicalSchema
/// forwards to this constant, so updating one place is sufficient.
enum PariSchema {
    static let canonical = Schema([
        Prediction.self,
        CalibrationSnapshot.self,
        PredictionTemplate.self,
        TrainingQuestion.self,
        FlashCard.self,
        AIPrediction.self,
        DuelPrediction.self,
        CoachMessage.self,
        TeamWorkspace.self,
        TeamPrediction.self,
        LifeForecast.self
    ])
}
