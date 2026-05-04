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
        let entry = loadEntry()
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadEntry() -> DueSoonEntry {
        do {
            let container = try PariWidgetStore.makeReadOnlyContainer()
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<Prediction>(
                predicate: #Predicate { $0.outcomeRaw == nil },
                sortBy: [SortDescriptor(\.resolutionDate)]
            )
            let active = (try? context.fetch(descriptor)) ?? []
            let next = active.first

            return DueSoonEntry(
                date: .now,
                claim: next?.claim,
                confidencePercent: next?.confidencePercent,
                predictionID: next?.id.uuidString,
                isOverdue: next?.isDue ?? false
            )
        } catch {
            return DueSoonEntry(date: .now, claim: nil, confidencePercent: nil,
                                predictionID: nil, isOverdue: false)
        }
    }
}

struct DueSoonWidgetView: View {
    let entry: DueSoonEntry

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
