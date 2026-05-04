import ActivityKit
import Foundation

struct PariActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var claim: String
        var resolutionDate: Date
        var hoursOverdue: Int
    }

    var predictionID: String
    var category: String
}
