import SwiftUI
import SwiftData
import WatchKit
import UserNotifications

struct WatchRootView: View {
    @Query(filter: #Predicate<CalibrationSnapshot> { _ in true },
           sort: \CalibrationSnapshot.computedAt, order: .reverse)
    private var snapshots: [CalibrationSnapshot]

    @Query(filter: #Predicate<Prediction> { $0.outcomeRaw == nil },
           sort: \Prediction.resolutionDate)
    private var active: [Prediction]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    scoreBlock
                    if !active.isEmpty {
                        dueBlock
                    }
                    NavigationLink {
                        WatchNewPrediction()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Quick predict")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.tint, in: Capsule())
                        .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
            }
            .navigationTitle("Présage")
        }
        .tint(Color(red: 0.184, green: 0.659, blue: 0.659))
    }

    private var scoreBlock: some View {
        VStack(spacing: 4) {
            Text("BRIER")
                .font(.system(size: 9, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(.secondary)
            Text(scoreString)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.tint)
            // Distinguish "fresh install, never computed" from "0
            // resolved" — the user with no snapshot yet shouldn't see
            // a misleading "0 resolved" stat.
            if let snap = snapshots.first {
                Text("\(snap.totalResolved) resolved")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                Text("Resolve a prediction to see your score")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private var dueBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DUE NEXT")
                .font(.system(size: 9, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(.secondary)
            ForEach(active.prefix(3)) { p in
                NavigationLink {
                    WatchResolutionView(prediction: p)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.claim)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(2)
                        HStack {
                            Text("\(p.confidencePercent)%")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.tint)
                            Text(p.isDue ? "Due" : "\(p.daysUntilResolution)d")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var scoreString: String {
        guard let s = snapshots.first?.brierScore else { return "—" }
        // Locale-aware: in `,`-decimal locales (most of Europe) the
        // hardcoded `String(format: "%.3f", ...)` produced "0.127" while
        // the rest of the app showed "0,127". Use the shared Foundation
        // formatter so the watch renders the same string the phone does.
        return s.formatted(.number.precision(.fractionLength(3)))
    }
}

struct WatchNewPrediction: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var claim: String = ""
    @State private var confidence: Int = 70

    private let steps = [50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 99]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Claim")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(1.0)
                    .foregroundStyle(.secondary)
                TextField("I will...", text: $claim, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: 13))

                Text("Confidence: \(confidence)%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tint)
                    .monospacedDigit()

                Picker("Confidence", selection: $confidence) {
                    ForEach(steps, id: \.self) { s in
                        Text("\(s)%").tag(s)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 80)

                Button {
                    save()
                } label: {
                    Text("Save · 1 week out")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(.tint, in: Capsule())
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .disabled(claim.count < 5)
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("Predict")
    }

    private func save() {
        let resolutionDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        let prediction = Prediction(
            claim: claim,
            resolutionCriteria: "Tap to add details on iPhone",
            confidencePercent: confidence,
            resolutionDate: resolutionDate,
            category: .behavior
        )
        context.insert(prediction)
        try? context.save()
        dismiss()
    }
}

struct WatchResolutionView: View {
    let prediction: Prediction
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showOriginal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(prediction.claim)
                    .font(.system(size: 14, weight: .semibold))
                Text(prediction.resolutionCriteria)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if !showOriginal && prediction.outcome == nil {
                    Text("DID THIS HAPPEN?")
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        outcomeButton("Yes", color: .green) { resolve(.yes) }
                        outcomeButton("No", color: .red) { resolve(.no) }
                    }
                    Button {
                        resolve(.ambiguous)
                    } label: {
                        Text("Ambiguous")
                            .font(.system(size: 11, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(.gray.opacity(0.2), in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else if let outcome = prediction.outcome {
                    HStack {
                        Text("You said")
                        Spacer()
                        Text("\(prediction.confidencePercent)%")
                            .foregroundStyle(.tint)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    HStack {
                        Text("Reality")
                        Spacer()
                        Text(outcome.rawValue.capitalized)
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(.horizontal, 6)
        }
    }

    private func outcomeButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(color, in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func resolve(_ outcome: ResolutionOutcome) {
        prediction.outcome = outcome
        prediction.resolvedAt = .now
        try? context.save()

        // Match the side-effects performed by PariEngine.resolve on iOS so
        // Watch resolutions stay first-class citizens.
        let predictionID = prediction.id
        Task {
            // Cancel pending iOS-scheduled reminders for this prediction.
            let center = UNUserNotificationCenter.current()
            let baseID = predictionID.uuidString
            let ids = ["-due", "-1d", "-3d", "-7d"].map { baseID + $0 }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }

        showOriginal = true
        WKInterfaceDevice.current().play(.success)
    }
}
