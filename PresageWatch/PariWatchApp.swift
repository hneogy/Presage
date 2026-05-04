import SwiftUI
import SwiftData

@main
struct PariWatchApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Prediction.self, CalibrationSnapshot.self])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Watch container init failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
        .modelContainer(container)
    }
}
