import UIKit
import UserNotifications
import OSLog

private let notifLogger = Logger(subsystem: "com.pari.neogy", category: "Notifications")

/// Routes notification taps into the engine's deep-link handler. Without
/// this delegate, every push (resolution reminders, Day-1/3/7 retention,
/// Sunday retro) silently no-ops when tapped.
@MainActor
final class PariNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PariNotificationDelegate()

    /// Set from `PariApp` during launch. Receives the deep-link URL built
    /// from each notification's userInfo so the engine can route it.
    var routeHandler: ((URL) -> Void)? {
        didSet {
            guard routeHandler != nil, !pendingURLs.isEmpty else { return }
            let queued = pendingURLs
            pendingURLs.removeAll()
            for url in queued {
                routeHandler?(url)
            }
        }
    }

    /// Buffer for taps that arrive before `routeHandler` is wired up
    /// (cold launch from a notification: the system can deliver the tap
    /// before `PariApp.task` finishes setting the handler). Without this,
    /// the very tap that launched the app would silently no-op.
    private var pendingURLs: [URL] = []

    func register() {
        UNUserNotificationCenter.current().delegate = self
    }

    private func dispatch(_ url: URL) {
        if let handler = routeHandler {
            handler(url)
        } else {
            pendingURLs.append(url)
        }
    }

    /// Show banner + sound even when the app is foreground — without this
    /// flag, foreground pushes are invisible.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions {
        return [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo

        // Resolution reminder format: userInfo["predictionID"] = UUID string
        if let id = userInfo["predictionID"] as? String {
            if let uuid = UUID(uuidString: id),
               let url = URL(string: "pari://resolve/\(uuid.uuidString)") {
                dispatch(url)
                return
            }
            // Malformed UUID — log it and fall through to a sensible
            // landing page so the tap isn't a silent no-op.
            notifLogger.warning("Notification carried invalid predictionID payload: \(id, privacy: .public)")
            if let fallback = URL(string: "pari://predictions") {
                dispatch(fallback)
                return
            }
        }

        // Generic deep link format used by retention pushes.
        if let link = userInfo["deepLink"] as? String {
            if let url = URL(string: link) {
                dispatch(url)
                return
            }
            notifLogger.warning("Notification carried invalid deepLink payload: \(link, privacy: .public)")
        }

        // Last-resort fallback so the user lands somewhere instead of
        // staring at a frozen lock screen after tapping the push.
        if let home = URL(string: "pari://home") {
            dispatch(home)
        }
    }
}
