import WidgetKit
import SwiftUI

@main
struct PariWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BrierScoreWidget()
        DueSoonWidget()
        SmartStackWidget()
        if #available(iOSApplicationExtension 16.1, *) {
            PariLiveActivity()
        }
    }
}
