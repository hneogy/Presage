import Testing
import Foundation
@testable import Pari

@Suite("ScoringEngine")
struct ScoringEngineTests {

    // MARK: - Brier Score

    @Test("Brier score: 100% confident, correct → 0.0")
    func brierPerfectCorrect() {
        let score = ScoringEngine.brierScore(confidencePercent: 99, outcome: true)
        #expect(abs(score - 0.0001) < 0.001)
    }

    @Test("Brier score: 50% confident, correct → 0.25")
    func brierCoinFlipCorrect() {
        let score = ScoringEngine.brierScore(confidencePercent: 50, outcome: true)
        #expect(abs(score - 0.25) < 0.001)
    }

    @Test("Brier score: 50% confident, incorrect → 0.25")
    func brierCoinFlipIncorrect() {
        let score = ScoringEngine.brierScore(confidencePercent: 50, outcome: false)
        #expect(abs(score - 0.25) < 0.001)
    }

    @Test("Brier score: 90% confident, incorrect → 0.81")
    func brierOverconfidentWrong() {
        let score = ScoringEngine.brierScore(confidencePercent: 90, outcome: false)
        #expect(abs(score - 0.81) < 0.001)
    }

    @Test("Brier score: 80% confident, correct → 0.04")
    func brierGoodCalibration() {
        let score = ScoringEngine.brierScore(confidencePercent: 80, outcome: true)
        #expect(abs(score - 0.04) < 0.001)
    }

    @Test("Brier score: 70% confident, incorrect → 0.49")
    func brierModerateWrong() {
        let score = ScoringEngine.brierScore(confidencePercent: 70, outcome: false)
        #expect(abs(score - 0.49) < 0.001)
    }

    // MARK: - Log Score

    @Test("Log score: 90% confident, correct → log2(0.9)")
    func logScoreCorrect() {
        let score = ScoringEngine.logScore(confidencePercent: 90, outcome: true)
        let expected = log2(0.9)
        #expect(abs(score - expected) < 0.001)
    }

    @Test("Log score: 90% confident, incorrect → log2(0.1)")
    func logScoreIncorrect() {
        let score = ScoringEngine.logScore(confidencePercent: 90, outcome: false)
        let expected = log2(0.1)
        #expect(abs(score - expected) < 0.001)
    }

    @Test("Log score: 50% correct → log2(0.5) = -1")
    func logScoreCoinFlip() {
        let score = ScoringEngine.logScore(confidencePercent: 50, outcome: true)
        #expect(abs(score - (-1.0)) < 0.001)
    }

    // MARK: - Confidence Snap

    @Test("Snap rounds to nearest step")
    func snapToNearest() {
        #expect(ConfidenceLevel.snap(52) == 50)
        #expect(ConfidenceLevel.snap(53) == 55)
        #expect(ConfidenceLevel.snap(67) == 65)
        #expect(ConfidenceLevel.snap(73) == 75)
        #expect(ConfidenceLevel.snap(97) == 95)
        #expect(ConfidenceLevel.snap(98) == 99)
    }

    // MARK: - Verbal Labels

    @Test("Verbal labels match confidence ranges")
    func verbalLabels() {
        #expect(ConfidenceLevel.verbalLabel(for: 50) == "Coin flip")
        #expect(ConfidenceLevel.verbalLabel(for: 60) == "Slight lean")
        #expect(ConfidenceLevel.verbalLabel(for: 70) == "Likely")
        #expect(ConfidenceLevel.verbalLabel(for: 80) == "Confident")
        #expect(ConfidenceLevel.verbalLabel(for: 90) == "Very confident")
        #expect(ConfidenceLevel.verbalLabel(for: 95) == "Near certain")
    }

    // MARK: - Quality Checker

    @Test("Quality: short claim is vague")
    func qualityShortClaim() {
        let flag = QualityChecker.assess(claim: "gym", criteria: "I will go to the gym 4 times")
        #expect(flag == .vague)
    }

    @Test("Quality: duplicate claim and criteria is vague")
    func qualityDuplicate() {
        let text = "I will finish the book by Friday"
        let flag = QualityChecker.assess(claim: text, criteria: text)
        #expect(flag == .vague)
    }

    @Test("Quality: well-specified passes")
    func qualityWellSpecified() {
        let flag = QualityChecker.assess(
            claim: "I will go to the gym at least 4 times this week",
            criteria: "4 or more check-ins on the gym app between Monday and Sunday"
        )
        #expect(flag == .wellSpecified)
    }
}
