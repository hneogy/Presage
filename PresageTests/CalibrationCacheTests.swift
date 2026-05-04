import Testing
import Foundation
import SwiftData
@testable import Pari

@Suite("CalibrationCache")
@MainActor
struct CalibrationCacheTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Prediction.self, CalibrationSnapshot.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Empty database produces snapshot with nil scores")
    func emptySnapshot() throws {
        let container = try makeContainer()
        let cache = CalibrationCache(modelContainer: container)
        let context = container.mainContext

        try cache.recompute(using: context)

        let descriptor = FetchDescriptor<CalibrationSnapshot>()
        let snapshots = try context.fetch(descriptor)

        #expect(snapshots.count == 1)
        #expect(snapshots.first?.brierScore == nil)
        #expect(snapshots.first?.totalResolved == 0)
    }

    @Test("Snapshot reflects resolved predictions")
    func populatedSnapshot() throws {
        let container = try makeContainer()
        let cache = CalibrationCache(modelContainer: container)
        let context = container.mainContext

        for confidence in [70, 80, 90] {
            let prediction = Prediction(
                claim: "Test \(confidence)",
                resolutionCriteria: "Specific yes condition",
                confidencePercent: confidence,
                resolutionDate: .now,
                category: .behavior
            )
            prediction.outcome = .yes
            prediction.resolvedAt = .now
            context.insert(prediction)
        }
        try context.save()

        try cache.recompute(using: context)

        let descriptor = FetchDescriptor<CalibrationSnapshot>()
        let snapshot = try context.fetch(descriptor).first
        #expect(snapshot != nil)
        #expect(snapshot?.totalResolved == 3)
        #expect(snapshot?.brierScore != nil)
    }

    @Test("Fudged predictions are excluded from headline score")
    func fudgedExcluded() throws {
        let container = try makeContainer()
        let cache = CalibrationCache(modelContainer: container)
        let context = container.mainContext

        let p1 = Prediction(claim: "Honest test 1", resolutionCriteria: "Specific yes",
                            confidencePercent: 80, resolutionDate: .now, category: .behavior)
        p1.outcome = .yes
        p1.resolvedAt = .now
        context.insert(p1)

        let p2 = Prediction(claim: "Fudged test", resolutionCriteria: "Specific yes",
                            confidencePercent: 90, resolutionDate: .now, category: .behavior)
        p2.outcome = .ambiguous
        p2.isFudged = true
        p2.resolvedAt = .now
        context.insert(p2)

        try context.save()
        try cache.recompute(using: context)

        let snap = try context.fetch(FetchDescriptor<CalibrationSnapshot>()).first
        // 1 honest yes at 80% → brier = 0.04
        #expect(abs((snap?.brierScore ?? -1) - 0.04) < 0.01)
    }
}
