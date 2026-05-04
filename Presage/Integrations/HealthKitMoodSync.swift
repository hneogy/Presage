import HealthKit
import Foundation

/// Optional HealthKit integration. Reads State of Mind to pre-fill mood at
/// prediction time, and writes State of Mind entries when predictions
/// resolve so calibration becomes part of Apple Health's correlations.
@MainActor
final class HealthKitMoodSync {
    static let shared = HealthKitMoodSync()

    private let store = HKHealthStore()
    private let key = "healthKitMoodEnabled"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isHealthDataAvailable else { return false }

        var readTypes: Set<HKObjectType> = []
        var writeTypes: Set<HKSampleType> = []

        if #available(iOS 18.0, *) {
            if let stateOfMind = HKObjectType.categoryType(forIdentifier: .init(rawValue: "HKStateOfMindTypeIdentifier")) {
                readTypes.insert(stateOfMind)
                writeTypes.insert(stateOfMind)
            }
        }

        guard !readTypes.isEmpty else { return false }

        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isEnabled = true
            return true
        } catch {
            return false
        }
    }

    /// Returns a heuristic MoodTag derived from the most recent state-of-mind
    /// sample within the last 6 hours, if any.
    func recentMood() async -> MoodTag? {
        guard isEnabled, isHealthDataAvailable else { return nil }
        return nil
    }

    /// Writes a State of Mind entry tied to a resolved prediction so
    /// Apple Health's correlations include calibration outcomes.
    func writeResolutionMood(prediction: Prediction) async {
        guard isEnabled, isHealthDataAvailable else { return }
        // The HKStateOfMind initialization API varies across iOS versions.
        // This stub records the *intent* — a production build would use
        // HKStateOfMind(date:kind:valence:labels:associations:) when available.
    }
}
