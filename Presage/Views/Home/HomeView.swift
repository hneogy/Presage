import SwiftUI
import SwiftData
import TipKit

struct HomeView: View {
    @Environment(PariEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    @Query(filter: #Predicate<CalibrationSnapshot> { _ in true },
           sort: \CalibrationSnapshot.computedAt, order: .reverse)
    private var snapshots: [CalibrationSnapshot]

    @Query(filter: #Predicate<Prediction> { $0.outcomeRaw == nil },
           sort: \Prediction.resolutionDate)
    private var activePredictions: [Prediction]

    @Query(filter: #Predicate<Prediction> { $0.outcomeRaw != nil },
           sort: \Prediction.resolvedAt, order: .reverse)
    private var resolvedPredictions: [Prediction]

    @State private var selectedHomePrediction: Prediction?

    private var snapshot: CalibrationSnapshot? { snapshots.first }
    private var dueSoon: [Prediction] { Array(activePredictions.prefix(3)) }
    private var totalPredictions: Int { activePredictions.count + resolvedPredictions.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                BrierScoreHero(
                    brierScore: snapshot?.brierScore,
                    totalResolved: snapshot?.totalResolved ?? 0,
                    previousScore: nil
                )
                .padding(.top, 8)

                statsRow
                resolvingSoonSection
                miniCalibrationSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.home(colorScheme))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PariBrandMark(size: 22)
                    .accessibilityLabel("Présage")
                    .accessibilityAddTraits(.isHeader)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsSheet()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DS.Palette.textSecondary)
                        .accessibilityLabel("Settings")
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $selectedHomePrediction) { prediction in
            PredictionDetailSheet(prediction: prediction)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            PariStatTile(
                "Active",
                value: "\(activePredictions.count)"
            )

            PariStatTile(
                "Hit Rate",
                value: hitRateString,
                coralAccent: true
            )

            PariStatTile(
                "Avg Conf",
                value: avgConfidenceString
            )
        }
    }

    private var avgConfidenceString: String {
        guard let avg = ScoringEngine.averageConfidence(
            activePredictions + resolvedPredictions
        ) else { return "—" }
        return "\(avg)%"
    }

    private var hitRateString: String {
        guard let rate = ScoringEngine.hitRate(resolvedPredictions) else { return "—" }
        return "\(Int((rate * 100).rounded()))%"
    }

    // MARK: - Resolving Soon

    @ViewBuilder
    private var resolvingSoonSection: some View {
        if !dueSoon.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    sectionHeader("Resolving Soon", count: dueSoon.count)
                    Spacer()
                    Button {
                        engine.activeTab = 1
                    } label: {
                        Text("see all")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DS.Palette.textSecondary)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(dueSoon) { prediction in
                        HomePredictionRow(prediction: prediction)
                            .onTapGesture {
                                if prediction.isDue {
                                    engine.resolvingPrediction = prediction
                                } else {
                                    selectedHomePrediction = prediction
                                }
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var miniCalibrationSection: some View {
        if let snap = snapshot, !snap.buckets.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("Calibration Curve", count: nil)

                PariCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            legendDot(color: DS.Palette.accent, label: "You")
                            legendDot(color: DS.Palette.chartPerfect, label: "Perfect")
                        }
                        CalibrationCurveChart(buckets: snap.buckets)
                            .frame(height: 220)
                    }
                }
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DS.Palette.textSecondary)
        }
    }

    private func sectionHeader(_ title: String, count: Int?) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DS.Palette.textPrimary)
            if let count {
                Text("\(count)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Palette.accentSecondary)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(
                        Capsule().fill(DS.Palette.accentSecondaryMuted)
                    )
            }
        }
    }
}

// MARK: - Home Prediction Row (compact)

struct HomePredictionRow: View {
    let prediction: Prediction

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(prediction.isDue ? DS.Palette.accentSecondaryMuted : DS.Palette.accentMuted)
                    .frame(width: 40, height: 40)
                Image(systemName: prediction.category.sfSymbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(prediction.isDue ? DS.Palette.accentSecondary : DS.Palette.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(prediction.claim)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("\(prediction.confidencePercent)%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.Palette.accent)
                        .monospacedDigit()

                    Circle()
                        .fill(DS.Palette.textTertiary)
                        .frame(width: 2, height: 2)

                    Text(timeText)
                        .font(.system(size: 11))
                        .foregroundStyle(prediction.isDue ? DS.Palette.accentSecondary : DS.Palette.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.Palette.textTertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DS.Palette.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(DS.Palette.separator, lineWidth: 0.5)
                )
        )
    }

    private var timeText: String {
        if prediction.isDue {
            return prediction.daysOverdue == 0 ? "Due today" : "\(prediction.daysOverdue)d overdue"
        }
        let d = prediction.daysUntilResolution
        return d == 0 ? "Due today" : "\(d)d left"
    }
}
