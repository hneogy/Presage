import Testing
import Foundation
@testable import Presage

@Suite("ScoringEngine bounds")
struct ScoringEngineBoundsTests {

    @Test("Brier is always within [0, 1] for any valid confidence")
    func brierBounded() {
        for c in 50...99 {
            let yesScore = ScoringEngine.brierScore(confidencePercent: c, outcome: true)
            let noScore = ScoringEngine.brierScore(confidencePercent: c, outcome: false)
            #expect(yesScore >= 0 && yesScore <= 1)
            #expect(noScore >= 0 && noScore <= 1)
        }
    }

    @Test("Brier stays bounded even for out-of-range confidence")
    func brierBoundedOutOfRange() {
        // Even though the UI snaps to 50–99, defensive callers may
        // pass anything. Should not crash, NaN, or escape [0, 1].
        for c in [-100, -1, 0, 100, 200, 1_000, Int.max, Int.min] {
            let s = ScoringEngine.brierScore(confidencePercent: c, outcome: true)
            #expect(s.isFinite)
            #expect(s >= 0 && s <= 1)
        }
    }

    @Test("Log score is finite for any input — no -Inf at the floor")
    func logScoreFinite() {
        for c in [-100, 0, 1, 50, 99, 100, 200] {
            let s = ScoringEngine.logScore(confidencePercent: c, outcome: true)
            let s2 = ScoringEngine.logScore(confidencePercent: c, outcome: false)
            #expect(s.isFinite)
            #expect(s2.isFinite)
        }
    }

    @Test("Log score floor is tighter than the prior 0.001 clamp")
    func logScoreFloorIsTight() {
        // Old behaviour collapsed all near-zero forecasts to log2(0.001) ≈ -9.97.
        // New floor at 1e-6 means very-confident-and-wrong predictions
        // produce distinct, much-more-punitive scores.
        let s = ScoringEngine.logScore(confidencePercent: 99, outcome: false)
        // 1 - 0.99 = 0.01, log2(0.01) ≈ -6.64
        #expect(abs(s - log2(0.01)) < 0.001)
    }

    @Test("Aggregate Brier on empty input returns nil")
    func aggregateEmpty() {
        #expect(ScoringEngine.aggregateBrier([]) == nil)
        #expect(ScoringEngine.aggregateLog([]) == nil)
    }

    @Test("Hit rate on empty input returns nil")
    func hitRateEmpty() {
        #expect(ScoringEngine.hitRate([]) == nil)
    }

    @Test("Calibration buckets cover all confidence levels")
    func bucketsCoverAllLevels() {
        let buckets = ScoringEngine.buildCalibrationBuckets([])
        #expect(buckets.count == ConfidenceLevel.allSteps.count)
        for bucket in buckets {
            #expect(bucket.predictionCount == 0)
        }
    }
}
