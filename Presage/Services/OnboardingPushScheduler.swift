import UserNotifications
import Foundation

/// The Day-1/3/7 push strategy. Capped at 3 pushes in the first 7 days so
/// we stay under the 6-push uninstall threshold.
///
/// Research basis: users who get 1 push in their first 90 days have 3×
/// retention. >6 pushes triggers 32% uninstall rate. Day-3 is the
/// canonical inflection point for iOS app churn (72% otherwise).
@MainActor
enum OnboardingPushScheduler {
    private static let day1ID = "com.pari.neogy.retention.day1"
    private static let day3ID = "com.pari.neogy.retention.day3"
    private static let day7ID = "com.pari.neogy.retention.day7"

    static func scheduleRetentionSequence() async {
        let center = UNUserNotificationCenter.current()
        // Cancel any prior retention sequence (e.g. after deleting the
        // first prediction and re-onboarding)
        center.removePendingNotificationRequests(withIdentifiers: [day1ID, day3ID, day7ID])

        // Day 1: 24h after install / first prediction
        let day1 = makeContent(
            title: "You locked in a prediction.",
            body: "It resolves in 6 days. Présage will ask you what happened first — your confidence stays hidden until you answer."
        )
        await schedule(id: day1ID, content: day1, daysFromNow: 1, hour: 19)

        // Day 3: the proven retention inflection point
        let day3 = makeContent(
            title: "Halfway there.",
            body: "Anything changed since you locked it in? You can edit the prediction or let it ride."
        )
        await schedule(id: day3ID, content: day3, daysFromNow: 3, hour: 19)

        // Day 7: the resolution moment — the wow moment
        let day7 = makeContent(
            title: "Time to resolve.",
            body: "Did it happen? Tap to answer first — Présage hides your confidence to keep you honest."
        )
        await schedule(id: day7ID, content: day7, daysFromNow: 7, hour: 9)
    }

    /// Cancels the welcome sequence — call when user has clearly engaged
    /// (e.g. returned to app on day 2, made a second prediction).
    static func cancelRetentionSequence() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [day1ID, day3ID, day7ID]
        )
    }

    private static func makeContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["deepLink": "pari://home"]
        return content
    }

    private static func schedule(id: String, content: UNNotificationContent, daysFromNow: Int, hour: Int) async {
        let cal = Calendar.current
        guard let target = cal.date(byAdding: .day, value: daysFromNow, to: .now) else { return }
        var components = cal.dateComponents([.year, .month, .day], from: target)
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
