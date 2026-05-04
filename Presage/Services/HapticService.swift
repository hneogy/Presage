import UIKit

enum HapticService {

    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func tick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func confidenceTick(at percent: Int) {
        let thresholds = [50, 80, 95]
        if thresholds.contains(percent) {
            heavy()
        } else {
            medium()
        }
    }
}
