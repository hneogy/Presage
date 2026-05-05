import Foundation
import OSLog
import SwiftData

private let sharedStoreLogger = Logger(subsystem: "com.pari.neogy", category: "SharedStore")

/// Single source of truth for the SwiftData store URL — used by the main
/// app, widget extension, and any future extensions. The store lives in
/// the App Group container so all targets share the same data.
///
/// Bug history: prior to audit pass 14, neither the main app nor the
/// widgets specified a URL on `ModelConfiguration`. SwiftData defaulted
/// to each target's Application Support directory, which is per-target,
/// not shared. Result: widgets read from an empty SQLite database and
/// always displayed "—". This module fixes that by making the App Group
/// URL the only valid container location.
enum PariSharedStore {

    /// The App Group identifier matching both targets' entitlements.
    static let appGroupID = "group.com.pari.neogy"

    /// The on-disk location of the shared SwiftData store. Returns nil
    /// if the App Group container can't be resolved (e.g. the
    /// entitlement is missing — should never happen in production).
    static var storeURL: URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        else { return nil }
        return container.appendingPathComponent("Pari.sqlite")
    }

    /// Builds a ModelConfiguration that points at the shared store. If
    /// the App Group is unavailable (unsigned debug build, simulator
    /// edge case), falls back to the default per-target location so the
    /// app still functions for the developer.
    ///
    /// References `PariSchema.canonical` (non-isolated) rather than
    /// CloudSyncManager.canonicalSchema directly so this helper itself
    /// can stay free of main-actor isolation requirements.
    static func sharedConfiguration(cloudKit: Bool) -> ModelConfiguration {
        if let url = storeURL {
            return ModelConfiguration(
                schema: PariSchema.canonical,
                url: url,
                cloudKitDatabase: cloudKit ? .private("iCloud.com.pari.neogy") : .none
            )
        }
        // App Group missing means widgets will silently read an empty store.
        // Log loudly and flip a persistent flag so Settings can warn the
        // user. We *don't* assertionFailure here: simulator and unit-test
        // hosts often lack the entitlement and the original symptom was
        // already a silent failure, which the flag now fixes.
        sharedStoreLogger.fault("App Group container unresolved — widgets will not see data")
        UserDefaults.standard.set(true, forKey: appGroupFallbackFlagKey)
        return ModelConfiguration(
            schema: PariSchema.canonical,
            cloudKitDatabase: cloudKit ? .private("iCloud.com.pari.neogy") : .none
        )
    }

    /// UserDefaults key flipped when the App Group container can't be
    /// resolved — Settings reads this to render a "widgets won't sync"
    /// warning instead of pretending everything is fine.
    static let appGroupFallbackFlagKey = "pari.appGroup.fallback"
}
