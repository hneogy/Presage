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

        // Pin to Gregorian: in non-Gregorian calendars (Hebrew, Persian)
        // weekday numbering can differ, so reading `weekday = 1` from a
        // user's `Calendar.current` would fire on the wrong day. We
        // attach the Gregorian calendar to the components so the trigger
        // resolves Sunday consistently regardless of the user's chosen
        // calendar system.
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.weekday = 1   // Sunday in Gregorian
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
