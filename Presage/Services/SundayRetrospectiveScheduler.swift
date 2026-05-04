import UserNotifications
import Foundation

/// Schedules a recurring Sunday 7pm notification with a calibration recap.
@MainActor
enum SundayRetrospectiveScheduler {
    static let identifier = "com.pari.neogy.sunday-retro"

    static func enable() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Sunday retrospective"
        content.body = "Tap to see this week's calibration."
        content.sound = .default
        content.userInfo = ["deepLink": "pari://coach"]

        var components = DateComponents()
        components.weekday = 1   // Sunday in iOS
        components.hour = 19
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
