import Foundation

struct CalibrationBucket: Codable, Sendable, Identifiable {
    let confidencePercent: Int
    let predictionCount: Int
    let hitCount: Int

    var id: Int { confidencePercent }

    var hitRate: Double {
        guard predictionCount > 0 else { return 0 }
        return Double(hitCount) / Double(predictionCount)
    }

    var hitRatePercent: Int {
        Int((hitRate * 100).rounded())
    }
}

struct CategoryScore: Codable, Sendable {
    let category: String
    let brierScore: Double
    let logScore: Double
    let count: Int
}

struct HorizonScore: Codable, Sendable {
    let horizon: String
    let brierScore: Double
    let count: Int
}

struct MoodScore: Codable, Sendable {
    let mood: String
    let brierScore: Double
    let count: Int
}
