import Foundation
import OSLog
import SwiftData

private let calibrationLogger = Logger(subsystem: "com.pari.neogy", category: "CalibrationSnapshot")

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
        get {
            guard !bucketData.isEmpty else { return [] }
            do {
                return try JSONDecoder().decode([CalibrationBucket].self, from: bucketData)
            } catch {
                calibrationLogger.error("Failed to decode buckets: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                bucketData = encoded
            } else {
                calibrationLogger.error("Failed to encode buckets; preserving previous data")
            }
        }
    }

    var categoryScores: [CategoryScore] {
        get {
            guard !categoryScoresData.isEmpty else { return [] }
            do {
                return try JSONDecoder().decode([CategoryScore].self, from: categoryScoresData)
            } catch {
                calibrationLogger.error("Failed to decode categoryScores: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                categoryScoresData = encoded
            } else {
                calibrationLogger.error("Failed to encode categoryScores; preserving previous data")
            }
        }
    }

    var horizonScores: [HorizonScore] {
        get {
            guard !horizonScoresData.isEmpty else { return [] }
            do {
                return try JSONDecoder().decode([HorizonScore].self, from: horizonScoresData)
            } catch {
                calibrationLogger.error("Failed to decode horizonScores: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                horizonScoresData = encoded
            } else {
                calibrationLogger.error("Failed to encode horizonScores; preserving previous data")
            }
        }
    }

    var moodScores: [MoodScore] {
        get {
            guard !moodScoresData.isEmpty else { return [] }
            do {
                return try JSONDecoder().decode([MoodScore].self, from: moodScoresData)
            } catch {
                calibrationLogger.error("Failed to decode moodScores: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                moodScoresData = encoded
            } else {
                calibrationLogger.error("Failed to encode moodScores; preserving previous data")
            }
        }
    }
}
