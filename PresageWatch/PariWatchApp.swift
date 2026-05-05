import SwiftUI
import SwiftData

@main
struct PariWatchApp: App {
    let container: ModelContainer

    init() {
        // Route through PariSharedStore so the watch reads the SAME
        // SQLite file the phone writes to (via the App Group container).
        // Pre-this-fix the watch had its own per-target store, so any
        // prediction made on the watch was invisible to the phone and
        // vice versa.
        //
        // Falls back to a per-target store if the App Group entitlement
        // isn't available — keeps the watch launchable in development
        // builds without the entitlement provisioning.
        let config = PariSharedStore.sharedConfiguration(cloudKit: false)
        do {
            container = try ModelContainer(
                for: PariSchema.canonical,
                configurations: [config]
            )
        } catch {
            // Final fallback: in-memory so the watch launches even if the
            // shared store is unreachable (provisioning hiccup, missing
            // entitlement during dev). The watch user sees no data; the
            // phone is unaffected.
            let fallback = ModelConfiguration(
                schema: PariSchema.canonical,
                isStoredInMemoryOnly: true
            )
            do {
                container = try ModelContainer(
                    for: PariSchema.canonical,
                    configurations: [fallback]
                )
            } catch {
                fatalError("Watch container init failed even on fallback: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
        .modelContainer(container)
    }
}
