import BackgroundTasks
import SwiftData
import Foundation

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
        try? BGTaskScheduler.shared.submit(recompute)

        let widget = BGAppRefreshTaskRequest(identifier: widgetRefreshIdentifier)
        widget.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 2)
        try? BGTaskScheduler.shared.submit(widget)
    }

    private static func handleRecompute(task: BGAppRefreshTask, container: ModelContainer) {
        schedule()

        let cache = CalibrationCache(modelContainer: container)

        let work = Task { @MainActor in
            let context = container.mainContext
            try? cache.recomputeIfStale(using: context)
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private static func handleWidgetRefresh(task: BGAppRefreshTask) {
        schedule()
        #if canImport(WidgetKit)
        if #available(iOS 17.0, *) {
            WidgetReloader.reloadAll()
        }
        #endif
        task.setTaskCompleted(success: true)
    }
}
