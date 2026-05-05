import WidgetKit
import SwiftUI
import SwiftData

struct BrierScoreEntry: TimelineEntry {
    let date: Date
    let brierScore: Double?
    let totalResolved: Int
    let activeCount: Int
}

struct BrierScoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> BrierScoreEntry {
        BrierScoreEntry(date: .now, brierScore: 0.127, totalResolved: 23, activeCount: 5)
    }

    func getSnapshot(in context: Context, completion: @escaping (BrierScoreEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BrierScoreEntry>) -> Void) {
        let entry = loadEntry()
        let next = Calendar.current.date(byAdding: .hour, value: 4, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> BrierScoreEntry {
        do {
            // Read from the SAME SQLite file the main app writes to.
            // Pre-pass-14 we built a fresh per-widget store and always
            // returned empty.
            let container = try PariWidgetStore.makeReadOnlyContainer()
            let context = ModelContext(container)

            let snapDescriptor = FetchDescriptor<CalibrationSnapshot>(
                sortBy: [SortDescriptor(\.computedAt, order: .reverse)]
            )
            let snap = (try? context.fetch(snapDescriptor))?.first

            let activeDescriptor = FetchDescriptor<Prediction>(
                predicate: #Predicate { $0.outcomeRaw == nil }
            )
            let active = (try? context.fetch(activeDescriptor)) ?? []

            return BrierScoreEntry(
                date: .now,
                brierScore: snap?.brierScore,
                totalResolved: snap?.totalResolved ?? 0,
                activeCount: active.count
            )
        } catch {
            return BrierScoreEntry(date: .now, brierScore: nil, totalResolved: 0, activeCount: 0)
        }
    }
}

struct BrierScoreWidgetView: View {
    let entry: BrierScoreEntry
    @Environment(\.widgetFamily) var family

    private var accessibilitySummary: String {
        guard entry.brierScore != nil else {
            return "No Brier score yet. Resolve at least one prediction."
        }
        return "Brier score \(scoreString). \(entry.totalResolved) resolved, \(entry.activeCount) active. Tap to open insights."
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                rectangularLockScreen
            case .accessoryCircular:
                circularLockScreen
            case .accessoryInline:
                Text("Brier: \(scoreString)")
            default:
                homeScreen
            }
        }
        // Deep-link the whole widget into the Insights tab so a tap
        // takes the user to the calibration curve that the score
        // summarizes — instead of a no-op tap.
        .widgetURL(URL(string: "pari://insights"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var homeScreen: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BRIER SCORE")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .kerning(1.2)

            Text(scoreString)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
                .contentTransition(.numericText())

            Spacer()

            HStack(spacing: 8) {
                Label("\(entry.totalResolved)", systemImage: "checkmark.circle")
                Label("\(entry.activeCount)", systemImage: "clock")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var rectangularLockScreen: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Brier")
                .font(.caption2.weight(.medium))
            Text(scoreString)
                .font(.title2.weight(.bold))
            Text("\(entry.activeCount) active")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var circularLockScreen: some View {
        VStack(spacing: 0) {
            Text("BRIER")
                .font(.system(size: 8, weight: .semibold))
            Text(scoreString)
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var scoreString: String {
        guard let s = entry.brierScore else { return "—" }
        return PariWidgetStore.formatBrier(s)
    }
}

struct BrierScoreWidget: Widget {
    let kind: String = "BrierScoreWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BrierScoreProvider()) { entry in
            BrierScoreWidgetView(entry: entry)
        }
        .configurationDisplayName("Brier Score")
        .description("Your current calibration score.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}
