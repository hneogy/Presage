import SwiftUI

extension DS {
    enum Motion {
        static let tapDuration: Double = 0.08
        static let tapScale: CGFloat = 0.97
        static let stateTransition: Double = 0.2
        static let chartDraw: Double = 0.6
        static let scoreReveal: Double = 0.4

        static let stateAnimation: Animation = .easeInOut(duration: stateTransition)
        static let chartAnimation: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: chartDraw)
        static let scoreSpring: Animation = .spring(response: 0.5, dampingFraction: 0.7)
        static let navigationSpring: Animation = .spring(response: 0.35, dampingFraction: 0.86)
    }
}
