import UIKit
import UserNotifications

/// Routes notification taps into the engine's deep-link handler. Without
/// this delegate, every push (resolution reminders, Day-1/3/7 retention,
/// Sunday retro) silently no-ops when tapped.
@MainActor
final class PariNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PariNotificationDelegate()

    /// Set from `PariApp` during launch. Receives the deep-link URL built
    /// from each notification's userInfo so the engine can route it.
    var routeHandler: ((URL) -> Void)?

    func register() {
        UNUserNotificationCenter.current().delegate = self
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
        if let id = userInfo["predictionID"] as? String,
           let uuid = UUID(uuidString: id),
           let url = URL(string: "pari://resolve/\(uuid.uuidString)") {
            routeHandler?(url)
            return
        }

        // Generic deep link format used by retention pushes.
        if let link = userInfo["deepLink"] as? String,
           let url = URL(string: link) {
            routeHandler?(url)
            return
        }
    }
}
