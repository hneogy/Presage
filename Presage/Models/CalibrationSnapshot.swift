import Foundation
import SwiftData

@Model
final class CalibrationSnapshot {
    @Attribute(.unique) var id: UUID
    var computedAt: Date
    var totalResolved: Int
    var brierScore: Double?
    var logScore: Double?
    var bucketData: Data
    var categoryScoresData: Data
    var horizonScoresData: Data
    var moodScoresData: Data

    init() {
        self.id = UUID()
        self.computedAt = .now
        self.totalResolved = 0
        self.brierScore = nil
        self.logScore = nil
        self.bucketData = Data()
        self.categoryScoresData = Data()
        self.horizonScoresData = Data()
        self.moodScoresData = Data()
    }

    var buckets: [CalibrationBucket] {
        get { (try? JSONDecoder().decode([CalibrationBucket].self, from: bucketData)) ?? [] }
        set { bucketData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var categoryScores: [CategoryScore] {
        get { (try? JSONDecoder().decode([CategoryScore].self, from: categoryScoresData)) ?? [] }
        set { categoryScoresData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var horizonScores: [HorizonScore] {
        get { (try? JSONDecoder().decode([HorizonScore].self, from: horizonScoresData)) ?? [] }
        set { horizonScoresData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var moodScores: [MoodScore] {
        get { (try? JSONDecoder().decode([MoodScore].self, from: moodScoresData)) ?? [] }
        set { moodScoresData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}
