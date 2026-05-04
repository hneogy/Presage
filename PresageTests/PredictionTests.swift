import Testing
import Foundation
@testable import Pari

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
}
