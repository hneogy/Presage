import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.1, *)
struct PariLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PariActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("RESOLVING NOW")
                        .font(.caption2.weight(.medium))
                        .kerning(1.2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(context.attributes.category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(context.state.claim)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.85))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "questionmark.diamond")
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.claim)
                        .font(.caption.weight(.medium))
                        .lineLimit(2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Tap to resolve")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "questionmark.diamond")
            } compactTrailing: {
                Text("Due")
                    .font(.caption2)
            } minimal: {
                Image(systemName: "questionmark.diamond")
            }
        }
    }
}
