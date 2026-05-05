import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

struct DueSoonEntry: TimelineEntry {
    let date: Date
    let claim: String?
    let confidencePercent: Int?
    let predictionID: String?
    let isOverdue: Bool
}

struct DueSoonProvider: TimelineProvider {
    func placeholder(in context: Context) -> DueSoonEntry {
        DueSoonEntry(date: .now, claim: "Will I finish the book by Friday?",
                     confidencePercent: 75, predictionID: nil, isOverdue: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (DueSoonEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DueSoonEntry>) -> Void) {
        let (entry, nextResolution) = loadEntryAndNextDue()

        // Schedule a second timeline entry exactly when the soonest
        // unresolved prediction crosses into "due" — that way the widget
        // flips from "Resolving soon" to "Overdue" the moment it should,
        // instead of waiting for the hourly refresh tick.
        //
        // Use `.atEnd` so iOS triggers a fresh `getTimeline` call right
        // after our last entry — that re-fetches the prediction so a
        // resolution or deletion that happened between now and the
        // future entry can't surface a stale claim. Cap the second entry
        // to within the next hour so the hourly refresh remains the
        // backstop for everything outside that window.
        var entries: [DueSoonEntry] = [entry]
        let baseRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        if let nextResolution, nextResolution > .now, nextResolution < baseRefresh {
            entries.append(DueSoonEntry(
                date: nextResolution,
                claim: entry.claim,
                confidencePercent: entry.confidencePercent,
                predictionID: entry.predictionID,
                isOverdue: true
            ))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func loadEntry() -> DueSoonEntry {
        loadEntryAndNextDue().0
    }

    private func loadEntryAndNextDue() -> (DueSoonEntry, Date?) {
        do {
            let container = try PariWidgetStore.makeReadOnlyContainer()
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<Prediction>(
                predicate: #Predicate { $0.outcomeRaw == nil },
                sortBy: [SortDescriptor(\.resolutionDate)]
            )
            let active = (try? context.fetch(descriptor)) ?? []
            let next = active.first

            let entry = DueSoonEntry(
                date: .now,
                claim: next?.claim,
                confidencePercent: next?.confidencePercent,
                predictionID: next?.id.uuidString,
                isOverdue: next?.isDue ?? false
            )
            return (entry, next?.resolutionDate)
        } catch {
            return (DueSoonEntry(date: .now, claim: nil, confidencePercent: nil,
                                 predictionID: nil, isOverdue: false), nil)
        }
    }
}

struct DueSoonWidgetView: View {
    let entry: DueSoonEntry

    private var widgetTapURL: URL {
        if let id = entry.predictionID, let url = URL(string: "pari://resolve/\(id)") {
            return url
        }
        return URL(string: "pari://predictions") ?? URL(string: "pari://home")!
    }

    private var accessibilitySummary: String {
        guard let claim = entry.claim, let pct = entry.confidencePercent else {
            return "Présage — no active predictions. Tap to open the predictions list."
        }
        let state = entry.isOverdue ? "Overdue" : "Resolving soon"
        return "\(state): \(claim). \(pct) percent confidence. Tap to resolve."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.isOverdue ? "OVERDUE" : "RESOLVING SOON")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(entry.isOverdue ? .red : .secondary)
                    .kerning(1.2)
                Spacer()
                if let pct = entry.confidencePercent {
                    Text("\(pct)%")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.2), in: Capsule())
                        .foregroundStyle(.tint)
                }
            }

            if let claim = entry.claim {
                Text(claim)
                    .font(.callout.weight(.medium))
                    .lineLimit(3)
                    .foregroundStyle(.primary)
            } else {
                Text("No active predictions")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(widgetTapURL)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }
}

struct DueSoonWidget: Widget {
    let kind: String = "DueSoonWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DueSoonProvider()) { entry in
            DueSoonWidgetView(entry: entry)
        }
        .configurationDisplayName("Resolving Soon")
        .description("Your next prediction to resolve.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
