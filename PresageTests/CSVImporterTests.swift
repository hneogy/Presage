import Testing
import Foundation
import SwiftData
@testable import Presage

@Suite("CSVImporter")
@MainActor
struct CSVImporterTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Prediction.self, CalibrationSnapshot.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Empty CSV returns zero imported")
    func emptyCSV() throws {
        let container = try makeContainer()
        let result = CSVImporter.import(csv: "", into: container.mainContext)
        #expect(result.imported == 0)
        #expect(result.skipped == 0)
    }

    @Test("Header-only CSV imports nothing")
    func headerOnly() throws {
        let container = try makeContainer()
        let result = CSVImporter.import(csv: "title,forecast,resolveby", into: container.mainContext)
        #expect(result.imported == 0)
    }

    @Test("Valid Fatebook-style row imports with snapped confidence")
    func fatebookRow() throws {
        let container = try makeContainer()
        let csv = """
        title,forecast,resolveby,resolution,criteria
        I will finish the book,0.75,2099-01-01,,The book is finished
        """
        let result = CSVImporter.import(csv: csv, into: container.mainContext)
        #expect(result.imported == 1)

        let predictions = try container.mainContext.fetch(FetchDescriptor<Prediction>())
        #expect(predictions.count == 1)
        let p = predictions.first!
        #expect(p.claim == "I will finish the book")
        // 0.75 → 75
        #expect(p.confidencePercent == 75)
    }

    @Test("Confidence given as percent integer is preserved")
    func percentInteger() throws {
        let container = try makeContainer()
        let csv = """
        title,confidence,resolveby
        Q,80,2099-01-01
        """
        let result = CSVImporter.import(csv: csv, into: container.mainContext)
        #expect(result.imported == 1)
        let p = try container.mainContext.fetch(FetchDescriptor<Prediction>()).first!
        #expect(p.confidencePercent == 80)
    }

    @Test("Confidence is clamped into the valid 50–99 range")
    func confidenceClamped() throws {
        let container = try makeContainer()
        let csv = """
        title,confidence,resolveby
        Way overconfident,150,2099-01-01
        Below floor,5,2099-01-01
        """
        let result = CSVImporter.import(csv: csv, into: container.mainContext)
        #expect(result.imported == 2)
        for p in try container.mainContext.fetch(FetchDescriptor<Prediction>()) {
            #expect(p.confidencePercent >= 50 && p.confidencePercent <= 99)
        }
    }

    @Test("Missing resolution date defaults to 30 days out without crashing")
    func missingResolutionDate() throws {
        let container = try makeContainer()
        let csv = """
        title,confidence
        I will,70
        """
        let result = CSVImporter.import(csv: csv, into: container.mainContext)
        #expect(result.imported == 1)
        let p = try container.mainContext.fetch(FetchDescriptor<Prediction>()).first!
        let delta = p.resolutionDate.timeIntervalSinceNow
        // 30 days ± 1 day
        #expect(delta > 28 * 86400 && delta < 32 * 86400)
    }

    @Test("Successful import increments predictionCount counter")
    func incrementsCounter() throws {
        UserDefaults.standard.set(0, forKey: "predictionCount")
        let container = try makeContainer()
        let csv = """
        title,confidence,resolveby
        A,70,2099-01-01
        B,80,2099-01-01
        C,60,2099-01-01
        """
        _ = CSVImporter.import(csv: csv, into: container.mainContext)
        let count = UserDefaults.standard.integer(forKey: "predictionCount")
        #expect(count >= 3)
        UserDefaults.standard.removeObject(forKey: "predictionCount")
    }
}
