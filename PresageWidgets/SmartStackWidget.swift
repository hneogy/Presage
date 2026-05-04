import WidgetKit
import SwiftUI
import SwiftData

/// Smart Stack candidate widget. Apple's algorithm surfaces this when
/// a prediction is due based on relevance signals (resolutionDate proximity).
struct SmartStackEntry: TimelineEntry {
    let date: Date
    let claim: String?
    let confidencePercent: Int?
    let predictionID: String?
    let isOverdue: Bool
    let relevance: TimelineEntryRelevance?
}

struct SmartStackProvider: TimelineProvider {
    func placeholder(in context: Context) -> SmartStackEntry {
        SmartStackEntry(date: .now, claim: "Will I finish the report by Friday?",
                        confidencePercent: 70, predictionID: nil, isOverdue: false, relevance: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SmartStackEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SmartStackEntry>) -> Void) {
        let entry = loadEntry()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> SmartStackEntry {
        do {
            let container = try PariWidgetStore.makeReadOnlyContainer()
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Prediction>(
                predicate: #Predicate { $0.outcomeRaw == nil },
                sortBy: [SortDescriptor(\.resolutionDate)]
            )
            let active = (try? context.fetch(descriptor)) ?? []
            let next = active.first
            let isOverdue = next?.isDue ?? false

            // Relevance score — Apple promotes higher scores to the Smart Stack
            let relevance: TimelineEntryRelevance? = {
                guard let next else { return nil }
                if next.isDue { return TimelineEntryRelevance(score: 100) }
                let hours = max(0, next.resolutionDate.timeIntervalSinceNow / 3600)
                if hours < 24 { return TimelineEntryRelevance(score: 90) }
                if hours < 72 { return TimelineEntryRelevance(score: 60) }
                return TimelineEntryRelevance(score: 30)
            }()

            return SmartStackEntry(
                date: .now,
                claim: next?.claim,
                confidencePercent: next?.confidencePercent,
                predictionID: next?.id.uuidString,
                isOverdue: isOverdue,
                relevance: relevance
            )
        } catch {
            return SmartStackEntry(date: .now, claim: nil, confidencePercent: nil,
                                   predictionID: nil, isOverdue: false, relevance: nil)
        }
    }
}

struct SmartStackWidgetView: View {
    let entry: SmartStackEntry

    var body: some View {
        ZStack {
            // Dynamic gradient background — coral when overdue, teal otherwise
            LinearGradient(
                colors: entry.isOverdue
                    ? [Color(red: 0.957, green: 0.659, blue: 0.541).opacity(0.45), Color.black]
                    : [Color(red: 0.184, green: 0.659, blue: 0.659).opacity(0.45), Color.black],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.isOverdue ? "RESOLVE NOW" : "DUE SOON")
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    if let pct = entry.confidencePercent {
                        Text("\(pct)%")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(entry.isOverdue
                                             ? Color(red: 0.957, green: 0.659, blue: 0.541)
                                             : Color(red: 0.184, green: 0.659, blue: 0.659))
                            .monospacedDigit()
                    }
                }
                if let claim = entry.claim {
                    Text(claim)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                } else {
                    Text("No active predictions")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct SmartStackWidget: Widget {
    let kind: String = "PariSmartStackWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SmartStackProvider()) { entry in
            SmartStackWidgetView(entry: entry)
        }
        .configurationDisplayName("Smart Stack")
        .description("Surfaces when a prediction needs you.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
