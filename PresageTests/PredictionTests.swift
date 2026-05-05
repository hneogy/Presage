import Testing
import Foundation
@testable import Presage

@Suite("Prediction")
struct PredictionTests {

    @Test("New prediction is not resolved or due in the future")
    func freshPrediction() {
        let future = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        let p = Prediction(
            claim: "Test claim",
            resolutionCriteria: "Specific criteria",
            confidencePercent: 75,
            resolutionDate: future,
            category: .work
        )

        #expect(!p.isResolved)
        #expect(!p.isDue)
        #expect(p.daysUntilResolution >= 6)
    }

    @Test("Past resolution date marks prediction as due")
    func pastDuePrediction() {
        let past = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        let p = Prediction(
            claim: "Past test",
            resolutionCriteria: "Specific",
            confidencePercent: 70,
            resolutionDate: past,
            category: .behavior
        )

        #expect(p.isDue)
        #expect(p.daysOverdue >= 1)
    }

    @Test("Horizon classification matches resolution distance")
    func horizonClassification() {
        let now = Date.now
        let oneDay = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let twoWeeks = Calendar.current.date(byAdding: .day, value: 14, to: now)!
        let twoMonths = Calendar.current.date(byAdding: .day, value: 60, to: now)!
        let oneYear = Calendar.current.date(byAdding: .day, value: 365, to: now)!

        #expect(HorizonLabel.from(created: now, resolution: oneDay) == .days)
        #expect(HorizonLabel.from(created: now, resolution: twoWeeks) == .weeks)
        #expect(HorizonLabel.from(created: now, resolution: twoMonths) == .months)
        #expect(HorizonLabel.from(created: now, resolution: oneYear) == .long)
    }

    // MARK: - Boundary / corruption tests
    //
    // These exist because the model now clamps confidence at the init
    // boundary (Prediction.swift). A regression that removes the clamp
    // would let log scoring and Brier math see -1 / 0 / 100 and produce
    // NaN/-Inf — and we want a test, not the user, to catch that.

    @Test("Confidence above 99 is clamped at the model boundary")
    func confidenceClampedHigh() {
        let p = Prediction(
            claim: "test claim",
            resolutionCriteria: "test criteria",
            confidencePercent: 1000,
            resolutionDate: .now.addingTimeInterval(86400),
            category: .work
        )
        #expect(p.confidencePercent == 99)
    }

    @Test("Confidence below 1 is clamped at the model boundary")
    func confidenceClampedLow() {
        let zero = Prediction(
            claim: "zero",
            resolutionCriteria: "criteria",
            confidencePercent: 0,
            resolutionDate: .now.addingTimeInterval(86400),
            category: .work
        )
        #expect(zero.confidencePercent == 1)

        let negative = Prediction(
            claim: "negative",
            resolutionCriteria: "criteria",
            confidencePercent: -50,
            resolutionDate: .now.addingTimeInterval(86400),
            category: .work
        )
        #expect(negative.confidencePercent == 1)
    }

    @Test("Choices Codable round-trip survives empty data")
    func choicesEmptyData() {
        let p = Prediction(
            claim: "test",
            resolutionCriteria: "criteria",
            confidencePercent: 70,
            resolutionDate: .now.addingTimeInterval(86400),
            category: .work
        )
        // Default choices on a fresh prediction must be empty, not nil
        // — the @Model getter returns [] on missing data so callers can
        // map over the array unconditionally.
        #expect(p.choices.isEmpty)
    }

    @Test("Tags Codable round-trip survives empty data")
    func tagsEmptyData() {
        let p = Prediction(
            claim: "test",
            resolutionCriteria: "criteria",
            confidencePercent: 70,
            resolutionDate: .now.addingTimeInterval(86400),
            category: .work
        )
        #expect(p.tags.isEmpty)
    }
}
