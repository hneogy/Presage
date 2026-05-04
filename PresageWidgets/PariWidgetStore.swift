import Foundation
import SwiftData

/// Widget-side mirror of the main app's PariSharedStore. Both targets
/// must point at the SAME SQLite file in the App Group container OR
/// the widget reads from an empty store. The App Group ID and schema
/// must stay in lockstep with the main app's CloudSyncManager.
///
/// Why we register the full canonical schema even though widgets only
/// fetch Prediction + CalibrationSnapshot: SwiftData migrates the store
/// to match the registered schema. If we register a subset, SwiftData
/// would try to drop the un-registered entity tables, which would lose
/// the user's training answers, flashcards, AI scores, and life
/// forecasts. Registering the full schema means the widget opens the
/// store read-only without triggering migration.
enum PariWidgetStore {
    static let appGroupID = "group.com.pari.neogy"

    static let canonicalSchema = Schema([
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

    static var storeURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("Pari.sqlite")
    }

    static func makeReadOnlyContainer() throws -> ModelContainer {
        let url = storeURL
        let config: ModelConfiguration = {
            if let url {
                return ModelConfiguration(
                    schema: canonicalSchema,
                    url: url,
                    cloudKitDatabase: .none
                )
            }
            return ModelConfiguration(schema: canonicalSchema, cloudKitDatabase: .none)
        }()
        return try ModelContainer(for: canonicalSchema, configurations: [config])
    }
}
