import Testing
import Foundation
import SwiftData
@testable import Presage

@Suite("RecurrenceEngine", .serialized)
@MainActor
struct RecurrenceEngineTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Prediction.self,
            PredictionTemplate.self,
            CalibrationSnapshot.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Waits long enough for the fire-and-forget Tasks (Spotlight indexer,
    /// Notification scheduler, Live Activity) that `spawnDuePredictions`
    /// detaches to settle. Without this the test's ModelContext gets
    /// reset while those Tasks still hold weak references to spawned
    /// Prediction instances, tripping SwiftData's "model destroyed" trap.
    /// 500 ms is empirically enough for Notification + Spotlight on the
    /// simulator; the real fix lives in production code (the audit's
    /// PariCoordinator actor recommendation).
    private func awaitSideEffects() async {
        try? await Task.sleep(for: .milliseconds(500))
    }

    @Test("Daily template spawns when never run before")
    func dailyFirstRun() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let template = PredictionTemplate(
            claim: "I will run today",
            resolutionCriteria: "Strava records a run",
            defaultConfidencePercent: 70,
            category: .behavior,
            recurrence: .daily
        )
        // Push startDate into the past so the template is eligible.
        template.startDate = Date(timeIntervalSinceNow: -3600)
        context.insert(template)

        RecurrenceEngine.spawnDuePredictions(in: context)
        await awaitSideEffects()

        let preds = try context.fetch(FetchDescriptor<Prediction>())
        #expect(preds.count == 1)
        #expect(template.lastSpawnedAt != nil)
    }

    @Test("Weekly template does not respawn within the week")
    func weeklyDebounce() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let template = PredictionTemplate(
            claim: "Weekly",
            resolutionCriteria: "End of week",
            defaultConfidencePercent: 70,
            category: .behavior,
            recurrence: .weekly
        )
        template.startDate = Date(timeIntervalSinceNow: -86_400)
        context.insert(template)

        RecurrenceEngine.spawnDuePredictions(in: context)
        RecurrenceEngine.spawnDuePredictions(in: context)
        RecurrenceEngine.spawnDuePredictions(in: context)
        await awaitSideEffects()

        let preds = try context.fetch(FetchDescriptor<Prediction>())
        #expect(preds.count == 1)
    }

    @Test("Monthly cadence uses calendar months — no 30-day drift")
    func monthlyUsesCalendar() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let template = PredictionTemplate(
            claim: "Monthly",
            resolutionCriteria: "End of month",
            defaultConfidencePercent: 70,
            category: .behavior,
            recurrence: .monthly
        )
        template.startDate = Date(timeIntervalSinceNow: -86_400)
        // Pretend it last spawned 31 days ago (longer than 30) — should
        // still trigger; calendar arithmetic, not interval.
        template.lastSpawnedAt = Date(timeIntervalSinceNow: -31 * 86_400)
        context.insert(template)

        RecurrenceEngine.spawnDuePredictions(in: context)
        await awaitSideEffects()

        let preds = try context.fetch(FetchDescriptor<Prediction>())
        #expect(preds.count == 1)
    }

    @Test("Inactive template never spawns")
    func inactiveSkipped() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let template = PredictionTemplate(
            claim: "Paused",
            resolutionCriteria: "X",
            defaultConfidencePercent: 70,
            category: .behavior,
            recurrence: .daily
        )
        template.isActive = false
        template.startDate = Date(timeIntervalSinceNow: -86_400)
        context.insert(template)

        RecurrenceEngine.spawnDuePredictions(in: context)

        let preds = try context.fetch(FetchDescriptor<Prediction>())
        #expect(preds.count == 0)
    }
}
