import Foundation
#if canImport(WidgetKit)
import WidgetKit

enum WidgetReloader {
    static func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func reload(_ kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
#else
enum WidgetReloader {
    static func reloadAll() {}
    static func reload(_ kind: String) {}
}
#endif
