import UserNotifications
import Foundation

@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()
    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// iOS allows at most 64 pending notifications per app. Above that,
    /// new schedule calls silently fail. This budget — combined with our
    /// 4 reminders per prediction (-due/-1d/-3d/-7d) and 3 retention pushes
    /// (Day-1/3/7) — means we want headroom.
    private static let maxPendingNotifications = 56

    func scheduleResolutionReminder(for prediction: Prediction) async {
        let center = UNUserNotificationCenter.current()
        let baseID = prediction.id.uuidString

        // Respect the user's notification-preview privacy preference.
        // Default true; when off, replace the inline claim with a
        // generic placeholder so a glance at the lock screen doesn't
        // leak a sensitive prediction's contents.
        let previewsOn: Bool = {
            if UserDefaults.standard.object(forKey: "notificationPreviewsEnabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "notificationPreviewsEnabled")
        }()
        let claimPreview = previewsOn
            ? String(prediction.claim.prefix(50))
            : "your prediction"

        let triggers: [(String, Date, String)] = [
            ("\(baseID)-due", prediction.resolutionDate,
             previewsOn ? "Time to resolve: \(claimPreview)" : "Time to resolve a prediction."),
            ("\(baseID)-1d", prediction.resolutionDate.addingTimeInterval(86400),
             "You have a prediction to resolve."),
            ("\(baseID)-3d", prediction.resolutionDate.addingTimeInterval(86400 * 3),
             previewsOn
                ? "Still waiting on your answer for \(claimPreview)."
                : "Still waiting on your answer."),
            ("\(baseID)-7d", prediction.resolutionDate.addingTimeInterval(86400 * 7),
             "Your prediction is a week overdue. Be honest with yourself."),
        ]

        // Prune the oldest pending requests to stay under the iOS limit.
        // Without this, scheduling silently fails once the queue is full.
        await pruneIfNeeded(adding: triggers.count, in: center)

        for (id, date, body) in triggers {
            guard date > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Présage"
            content.body = body
            content.sound = .default
            content.userInfo = ["predictionID": prediction.id.uuidString]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            try? await center.add(request)
        }
    }

    /// If we'd push past the budget, drop the latest-scheduled
    /// (furthest-future) pending requests to make room. Soonest-due
    /// reminders are the most important — those should never be the ones
    /// dropped.
    private func pruneIfNeeded(adding count: Int, in center: UNUserNotificationCenter) async {
        let pending = await center.pendingNotificationRequests()
        let target = Self.maxPendingNotifications - count
        guard pending.count > target else { return }

        // Sort by trigger date, latest first; drop the latest.
        let datedRequests = pending.compactMap { req -> (UNNotificationRequest, Date)? in
            guard let trigger = req.trigger as? UNCalendarNotificationTrigger,
                  let date = trigger.nextTriggerDate() else { return nil }
            return (req, date)
        }
        let sortedByLatest = datedRequests.sorted { $0.1 > $1.1 }
        let toRemove = sortedByLatest.prefix(pending.count - target).map(\.0.identifier)
        center.removePendingNotificationRequests(withIdentifiers: toRemove)
    }

    func cancelReminder(for predictionID: UUID) async {
        let baseID = predictionID.uuidString
        let ids = ["-due", "-1d", "-3d", "-7d"].map { baseID + $0 }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
