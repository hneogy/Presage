import Foundation
import SwiftData

/// Computes Pari's claim on the canonical forecasting benchmark map.
/// Where do Pari users sit relative to ForecastBench LLMs, Metaculus,
/// Manifold, and Tetlock-style superforecasters?
///
/// The actual median across users requires an opt-in aggregation
/// service. This service computes the *individual* user's number and
/// compares it against published benchmarks. When the leaderboard
/// service is opted in, the user's Brier flows up anonymously.
@MainActor
enum PariMedianBenchmark {

    struct BenchmarkPoint: Identifiable, Hashable {
        var id: String { name }
        let name: String
        let brierScore: Double
        let citation: String
        let isPariUser: Bool
    }

    /// Static benchmark anchors from public sources. Updated quarterly.
    static let canonical: [BenchmarkPoint] = [
        BenchmarkPoint(
            name: "Tetlock Superforecasters",
            brierScore: 0.081,
            citation: "ForecastBench (ICLR 2025)",
            isPariUser: false
        ),
        BenchmarkPoint(
            name: "GPT-4.5",
            brierScore: 0.101,
            citation: "ForecastBench, late 2025",
            isPariUser: false
        ),
        BenchmarkPoint(
            name: "Metaculus (community)",
            brierScore: 0.111,
            citation: "Metaculus public Brier",
            isPariUser: false
        ),
        BenchmarkPoint(
            name: "Manifold Markets",
            brierScore: 0.168,
            citation: "Manifold platform-wide",
            isPariUser: false
        ),
        BenchmarkPoint(
            name: "Typical adult (Tetlock baseline)",
            brierScore: 0.20,
            citation: "Tetlock (2005)",
            isPariUser: false
        ),
        BenchmarkPoint(
            name: "Random guessing",
            brierScore: 0.25,
            citation: "Mathematical floor",
            isPariUser: false
        ),
    ]

    /// Pari median Brier across all opted-in users worldwide.
    /// Currently a placeholder until the aggregation service is live.
    /// Updated via remote config or static bundle on app update.
    static let pariMedian: Double = 0.165

    /// Returns the user's position on the benchmark map.
    static func userPosition(brier: Double) -> Int {
        // Where does the user sit in the sorted list?
        var allPoints = canonical
        allPoints.append(BenchmarkPoint(name: "Présage median", brierScore: pariMedian,
                                         citation: "Présage aggregate, opt-in", isPariUser: false))
        allPoints.sort { $0.brierScore < $1.brierScore }

        let position = allPoints.firstIndex { $0.brierScore > brier } ?? allPoints.count
        return position
    }

    /// Comparison statement: how the user compares to the field.
    static func comparison(brier: Double) -> String {
        if brier < 0.081 { return "You're scoring better than published superforecasters." }
        if brier < 0.101 { return "You're scoring better than GPT-4.5 on ForecastBench." }
        if brier < 0.111 { return "You're scoring better than the Metaculus community." }
        if brier < 0.168 { return "You're scoring better than Manifold platform-wide." }
        if brier < pariMedian { return "You're scoring better than the median Pari user." }
        if brier < 0.20 { return "You're above the Tetlock baseline for typical adults." }
        if brier < 0.25 { return "You're below average — but still better than random." }
        return "Worse than random guessing. The slider goes both ways."
    }
}
