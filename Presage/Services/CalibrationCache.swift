import Foundation
import SwiftData

actor CalibrationCache {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
    func recompute(using context: ModelContext) throws {
        let descriptor = FetchDescriptor<Prediction>(
            predicate: #Predicate<Prediction> { $0.outcomeRaw != nil }
        )
        let resolved = try context.fetch(descriptor)

        let scorable = resolved.filter { !$0.isFudged && ($0.outcome == .yes || $0.outcome == .no) }

        let snapshotDescriptor = FetchDescriptor<CalibrationSnapshot>(
            sortBy: [SortDescriptor(\.computedAt, order: .reverse)]
        )
        let existing = try context.fetch(snapshotDescriptor)

        let snapshot: CalibrationSnapshot
        if let first = existing.first {
            snapshot = first
        } else {
            snapshot = CalibrationSnapshot()
            context.insert(snapshot)
        }

        snapshot.computedAt = .now
        snapshot.totalResolved = resolved.count
        snapshot.brierScore = ScoringEngine.aggregateBrier(scorable)
        snapshot.logScore = ScoringEngine.aggregateLog(scorable)
        snapshot.buckets = ScoringEngine.buildCalibrationBuckets(scorable)
        snapshot.categoryScores = ScoringEngine.categoryScores(scorable)
        snapshot.horizonScores = ScoringEngine.horizonScores(scorable)
        snapshot.moodScores = ScoringEngine.moodScores(scorable)

        try context.save()
    }

    @MainActor
    func recomputeIfStale(using context: ModelContext) throws {
        let snapshotDescriptor = FetchDescriptor<CalibrationSnapshot>(
            sortBy: [SortDescriptor(\.computedAt, order: .reverse)]
        )
        let snapshots = try context.fetch(snapshotDescriptor)

        let predDescriptor = FetchDescriptor<Prediction>(
            predicate: #Predicate<Prediction> { $0.resolvedAt != nil },
            sortBy: [SortDescriptor(\.resolvedAt, order: .reverse)]
        )
        let latestResolved = try context.fetch(predDescriptor).first

        if let snap = snapshots.first, let latest = latestResolved?.resolvedAt {
            if latest <= snap.computedAt { return }
        }

        try recompute(using: context)
    }
}
