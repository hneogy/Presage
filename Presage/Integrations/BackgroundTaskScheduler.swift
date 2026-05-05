import BackgroundTasks
import OSLog
import SwiftData
import Foundation

private let bgLogger = Logger(subsystem: "com.pari.neogy", category: "BackgroundTask")

enum BackgroundTaskScheduler {
    static let recomputeIdentifier = "com.pari.neogy.recompute"
    static let widgetRefreshIdentifier = "com.pari.neogy.widgetrefresh"

    static func register(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: recomputeIdentifier,
            using: nil
        ) { task in
            // Defensive cast — iOS could in theory dispatch a different
            // task subtype if the registration metadata changes between
            // launches. Force-casting in a system callback is a crash;
            // a soft cast plus completion is the correct shape.
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleRecompute(task: refreshTask, container: modelContainer)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: widgetRefreshIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleWidgetRefresh(task: refreshTask)
        }
    }

    static func schedule() {
        let recompute = BGAppRefreshTaskRequest(identifier: recomputeIdentifier)
        recompute.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 6)
        do {
            try BGTaskScheduler.shared.submit(recompute)
        } catch {
            bgLogger.error("Failed to submit recompute task: \(error.localizedDescription, privacy: .public)")
        }

        let widget = BGAppRefreshTaskRequest(identifier: widgetRefreshIdentifier)
        widget.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 2)
        do {
            try BGTaskScheduler.shared.submit(widget)
        } catch {
            bgLogger.error("Failed to submit widget refresh task: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func handleRecompute(task: BGAppRefreshTask, container: ModelContainer) {
        schedule()

        // Guard against double-completion: setTaskCompleted must be called
        // exactly once, but both the work task and expiration handler can race.
        let completion = CompletionLatch(task: task)

        let work = Task { @MainActor in
            let cache = CalibrationCache(modelContainer: container)
            // Use a dedicated context rather than `container.mainContext`
            // so background recompute doesn't churn the change-tracker the
            // user's foreground @Query views are observing if the user
            // happens to launch the app while this task is mid-flight.
            let context = ModelContext(container)
            do {
                try cache.recomputeIfStale(using: context)
                completion.complete(success: true)
            } catch {
                bgLogger.error("Recompute failed: \(error.localizedDescription, privacy: .public)")
                completion.complete(success: false)
            }
        }

        task.expirationHandler = {
            work.cancel()
            completion.complete(success: false)
        }
    }

    /// Ensures `setTaskCompleted` is invoked at most once.
    private final class CompletionLatch: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        private let task: BGTask
        init(task: BGTask) { self.task = task }
        func complete(success: Bool) {
            lock.lock()
            defer { lock.unlock() }
            guard !done else { return }
            done = true
            task.setTaskCompleted(success: success)
        }
    }

    private static func handleWidgetRefresh(task: BGAppRefreshTask) {
        schedule()
        // WidgetCenter is MainActor-isolated; the BGTask handler runs
        // on a background queue, so dispatch the reload onto Main
        // before completing the task. Without this hop the reload
        // either logged a runtime warning or silently no-op'd
        // depending on the iOS build.
        #if canImport(WidgetKit)
        if #available(iOS 17.0, *) {
            Task { @MainActor in
                WidgetReloader.reloadAll()
                task.setTaskCompleted(success: true)
            }
            return
        }
        #endif
        task.setTaskCompleted(success: true)
    }
}
