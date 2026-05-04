import SwiftUI
import SwiftData
import Foundation

/// Optional iCloud sync. Off by default to preserve Pari's privacy-first
/// posture. When the user opts in, the model container is rebuilt with
/// CloudKit private database.
///
/// Why opt-in: Pari is a personal mirror; sync introduces resolution-fudging
/// risk (resolve on phone, second-guess on iPad). Users who want it can
/// enable it explicitly.
@MainActor
final class CloudSyncManager {
    static let shared = CloudSyncManager()

    private let key = "cloudSyncEnabled"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// Forwards to the non-isolated `PariSchema.canonical` so PariSharedStore
    /// and any non-main-actor callsite (App Intents, widget bridges) can
    /// reach the same schema constant without a main-actor hop.
    static var canonicalSchema: Schema { PariSchema.canonical }

    /// Build a ModelContainer using the user's current sync preference.
    /// Three-tier fallback: cloud-or-local → local-only → in-memory.
    /// Migration failure should never crash the app on first launch.
    ///
    /// All paths now go through `PariSharedStore.sharedConfiguration` so
    /// the main app and widget extension read from the SAME SQLite file.
    /// Pre-pass-14 they read separate stores — widgets always empty.
    static func makeContainer() -> ModelContainer {
        let cloudEnabled = UserDefaults.standard.bool(forKey: "cloudSyncEnabled")

        let primary = PariSharedStore.sharedConfiguration(cloudKit: cloudEnabled)
        if let container = try? ModelContainer(for: canonicalSchema, configurations: [primary]) {
            return container
        }

        // Tier 2 — local-only fallback (CloudKit may have failed to authorize).
        let local = PariSharedStore.sharedConfiguration(cloudKit: false)
        if let container = try? ModelContainer(for: canonicalSchema, configurations: [local]) {
            return container
        }

        // Tier 3 — in-memory only. Loses persistence this launch but keeps
        // the app launchable. The user can retry; we never crash.
        let memory = ModelConfiguration(schema: canonicalSchema, isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: canonicalSchema, configurations: [memory]) {
            return container
        }

        // Final guarantee: a bare-schema container. If this fails, the
        // SDK is broken; falling through to a trap here is the only
        // option, but every plausible failure mode has been handled above.
        do {
            return try ModelContainer(for: canonicalSchema)
        } catch {
            fatalError("SwiftData container creation failed at every fallback tier: \(error)")
        }
    }
}
