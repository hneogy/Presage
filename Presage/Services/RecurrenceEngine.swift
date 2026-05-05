import Foundation
import SwiftData

/// Spawns predictions from active templates on the appropriate schedule.
/// Called on app foreground and via background refresh.
enum RecurrenceEngine {

    @MainActor
    static func spawnDuePredictions(in context: ModelContext) {
        let descriptor = FetchDescriptor<PredictionTemplate>(
            predicate: #Predicate<PredictionTemplate> { $0.isActive == true }
        )
        guard let templates = try? context.fetch(descriptor) else { return }

        let now = Date.now
        for template in templates {
            if shouldSpawn(template: template, now: now) {
                spawn(from: template, at: now, in: context)
                template.lastSpawnedAt = now
            }
        }
        try? context.save()
    }

    private static func shouldSpawn(template: PredictionTemplate, now: Date) -> Bool {
        guard now >= template.startDate else { return false }
        guard let last = template.lastSpawnedAt else { return true }

        // For monthly recurrence, fixed-interval seconds drift across
        // 28/30/31-day months. Use Calendar arithmetic so "monthly" means
        // "same day next month" the way users read it. Other patterns are
        // exact-day cadences and remain interval-based.
        switch template.recurrence {
        case .monthly:
            let nextDue = Calendar.current.date(byAdding: .month, value: 1, to: last) ?? last
            return now >= nextDue.addingTimeInterval(-60)
        case .daily, .weekly, .biweekly:
            let interval = TimeInterval(template.recurrence.intervalDays * 86400)
            return now.timeIntervalSince(last) >= interval - 60
        }
    }

    @MainActor
    private static func spawn(from template: PredictionTemplate, at date: Date, in context: ModelContext) {
        let resolutionDate = Calendar.current.date(byAdding: .day, value: template.horizonDays, to: date) ?? date
        let prediction = Prediction(
            claim: template.claim,
            resolutionCriteria: template.resolutionCriteria,
            confidencePercent: template.defaultConfidencePercent,
            resolutionDate: resolutionDate,
            category: template.category,
            templateID: template.id
        )
        context.insert(prediction)

        PariEngine.recordCreation()

        Task {
            await NotificationScheduler.shared.scheduleResolutionReminder(for: prediction)
            await SpotlightIndexer.index(prediction)
            LiveActivityManager.startActivity(for: prediction)
        }

        WidgetReloader.reloadAll()
    }
}
