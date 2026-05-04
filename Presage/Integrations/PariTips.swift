import TipKit
import Foundation

@available(iOS 17.0, *)
struct BrierScoreExplanationTip: Tip {
    static let firstResolutionEvent = Event(id: "firstResolutionCompleted")

    var title: Text {
        Text("What is a Brier score?")
    }

    var message: Text? {
        Text("It measures how well-calibrated your predictions are. 0 is perfect. 0.25 is random guessing. Lower is better — the goal is to get closer to the diagonal line over time.")
    }

    var image: Image? {
        Image(systemName: "chart.line.uptrend.xyaxis")
    }

    var rules: [Rule] {
        #Rule(Self.firstResolutionEvent) { $0.donations.count >= 1 }
    }
}

@available(iOS 17.0, *)
struct ResolutionHonestyTip: Tip {
    var title: Text {
        Text("Why don't we show your confidence?")
    }

    var message: Text? {
        Text("If you saw your prediction first, you'd anchor on it. Answering blind is the only way to be honest with yourself.")
    }

    var image: Image? {
        Image(systemName: "eye.slash")
    }
}

@available(iOS 17.0, *)
struct CalibrationCurveTip: Tip {
    static let viewedHomeTenTimes = Event(id: "viewedHomeTenTimes")

    var title: Text {
        Text("Reading the curve")
    }

    var message: Text? {
        Text("The diagonal is perfect calibration. Dots below mean you were overconfident at that level. Dots above mean you were too cautious.")
    }

    var image: Image? {
        Image(systemName: "chart.dots.scatter")
    }

    var rules: [Rule] {
        #Rule(Self.viewedHomeTenTimes) { $0.donations.count >= 10 }
    }
}

import SwiftUI
