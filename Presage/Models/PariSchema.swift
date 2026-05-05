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
/// Adding a new @Model: register it on the latest `PariSchemaV*` below
/// (NOT just on `canonical`) so the migration plan can express any
/// future schema change. `canonical` forwards to the latest version's
/// schema, so callers continue to use it unchanged.
enum PariSchema {
    /// Latest schema. Always points at the most recent `PariSchemaV*`
    /// version. Containers are constructed against this; the migration
    /// plan handles upgrades from any earlier version.
    static let canonical = Schema(versionedSchema: PariSchemaV1.self)

    /// Plan that ferries existing on-device stores to the latest schema.
    /// Currently only registers V1 — when V2 lands, add a
    /// `MigrationStage.lightweight(fromVersion: PariSchemaV1.self,
    /// toVersion: PariSchemaV2.self)` (or `.custom(...)` for non-additive
    /// changes) and bump `canonical` to point at V2.
    static let migrationPlan: any SchemaMigrationPlan.Type = PariMigrationPlan.self
}

enum PariSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
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
        ]
    }
}

enum PariMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PariSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migrations yet — V1 is the only schema. Future versions:
        // append `.lightweight` for additive changes, `.custom(...)` for
        // anything that needs hand-rolled transformation.
        []
    }
}
