import SwiftUI
import SwiftData

struct PredictionListView: View {
    @Environment(PariEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    @Query(filter: #Predicate<Prediction> { $0.outcomeRaw == nil },
           sort: \Prediction.resolutionDate)
    private var activePredictions: [Prediction]

    @State private var selectedFilter: PredictionFilter = .all
    @State private var selectedDetail: Prediction?
    @State private var editingPrediction: Prediction?
    @State private var deletingPrediction: Prediction?

    private enum PredictionFilter: String, CaseIterable {
        case all = "All"
        case overdue = "Due"
        case thisWeek = "Week"

        func matches(_ prediction: Prediction) -> Bool {
            switch self {
            case .all: return true
            case .overdue: return prediction.isDue
            case .thisWeek:
                let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: .now)
                    ?? Date(timeIntervalSinceNow: 7 * 86400)
                return prediction.resolutionDate <= weekFromNow
            }
        }
    }

    private var filtered: [Prediction] {
        activePredictions.filter { selectedFilter.matches($0) }
    }

    private var overdue: [Prediction] { filtered.filter { $0.isDue } }

    private var thisWeek: [Prediction] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 7, to: .now)
            ?? Date(timeIntervalSinceNow: 7 * 86400)
        return filtered.filter {
            !$0.isDue && $0.resolutionDate <= cutoff
        }
    }

    private var thisMonth: [Prediction] {
        filtered.filter {
            !$0.isDue &&
            $0.daysUntilResolution > 7 &&
            $0.daysUntilResolution <= 30
        }
    }

    private var later: [Prediction] {
        filtered.filter { !$0.isDue && $0.daysUntilResolution > 30 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                filterBar.padding(.bottom, 20)

                if filtered.isEmpty {
                    PariEmptyState(
                        icon: "wand.and.stars",
                        title: "Nothing to track yet",
                        message: "Tap the + to make your first prediction.",
                        actionTitle: "New prediction"
                    ) {
                        engine.showNewPrediction = true
                    }
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 28, pinnedViews: []) {
                        predictionSection("Overdue", predictions: overdue, isOverdue: true)
                        predictionSection("This Week", predictions: thisWeek)
                        predictionSection("This Month", predictions: thisMonth)
                        predictionSection("Later", predictions: later)
                    }
                    .padding(.bottom, 140)
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.predict(colorScheme))
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedDetail) { prediction in
            PredictionDetailSheet(prediction: prediction)
                .presentationDetents([.medium])
        }
        .sheet(item: $editingPrediction) { prediction in
            EditPredictionSheet(prediction: prediction)
        }
        .confirmationDialog(
            "Delete prediction?",
            isPresented: Binding(
                get: { deletingPrediction != nil },
                set: { if !$0 { deletingPrediction = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let prediction = deletingPrediction {
                    engine.deletePrediction(prediction, in: context)
                    deletingPrediction = nil
                }
            }
        } message: {
            Text("This will permanently remove this prediction and its history.")
        }
        .onAppear {
            // Honor any pending deep link / Spotlight tap that landed on
            // this tab. Without this, every notification, intent, and
            // Spotlight result that asked Pari to open a specific
            // prediction would silently fail.
            engine.resolvePending(from: activePredictions)
        }
        .onChange(of: engine.pendingDeepLinkPredictionID) { _, _ in
            engine.resolvePending(from: activePredictions)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                WhisperLabel(text: "Your")
                Text("Predictions")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .kerning(-0.6)
            }
            Spacer()

            ZStack {
                Circle()
                    .fill(DS.Palette.surfaceTertiary)
                    .frame(width: 40, height: 40)
                Text("\(activePredictions.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Palette.accentSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PredictionFilter.allCases, id: \.self) { filter in
                    let count = countFor(filter)
                    PariChip(
                        label: count > 0 ? "\(filter.rawValue) · \(count)" : filter.rawValue,
                        isSelected: selectedFilter == filter,
                        tint: filter == .overdue ? DS.Palette.accentSecondary : DS.Palette.accent
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            selectedFilter = filter
                        }
                        HapticService.light()
                    }
                }
            }
        }
    }

    private func countFor(_ filter: PredictionFilter) -> Int {
        switch filter {
        case .all: return activePredictions.count
        case .overdue: return activePredictions.filter { $0.isDue }.count
        case .thisWeek:
            let w = Calendar.current.date(byAdding: .day, value: 7, to: .now)
                ?? Date(timeIntervalSinceNow: 7 * 86400)
            return activePredictions.filter { $0.resolutionDate <= w }.count
        }
    }

    // MARK: - Section

    @ViewBuilder
    private func predictionSection(_ title: String, predictions: [Prediction], isOverdue: Bool = false) -> some View {
        if !predictions.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    WhisperLabel(text: title, color: isOverdue ? DS.Palette.accentSecondary : DS.Palette.textTertiary)
                    Spacer()
                    Text("\(predictions.count)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(DS.Palette.textTertiary)
                        .monospacedDigit()
                }

                VStack(spacing: 10) {
                    ForEach(predictions) { prediction in
                        PredictionListItem(prediction: prediction, isOverdue: isOverdue)
                            .onTapGesture {
                                if prediction.isDue {
                                    engine.resolvingPrediction = prediction
                                } else {
                                    selectedDetail = prediction
                                }
                            }
                            .contextMenu {
                                Button {
                                    selectedDetail = prediction
                                } label: {
                                    Label("View details", systemImage: "info.circle")
                                }
                                if !prediction.isResolved {
                                    Button {
                                        editingPrediction = prediction
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                }
                                Button(role: .destructive) {
                                    deletingPrediction = prediction
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Redesigned List Item

struct PredictionListItem: View {
    let prediction: Prediction
    var isOverdue: Bool = false

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left rail — accent color strip + icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOverdue ? DS.Palette.accentSecondaryMuted : DS.Palette.accentMuted)
                    .frame(width: 44, height: 44)

                Image(systemName: prediction.category.sfSymbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isOverdue ? DS.Palette.accentSecondary : DS.Palette.accent)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(prediction.claim)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Palette.textPrimary)
                        .lineLimit(2)

                    if isOverdue && differentiate {
                        // Differentiate-Without-Color users can't rely on
                        // the coral border to mark overdue items, so we
                        // surface a glyph alongside the claim.
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.Palette.accentSecondary)
                            .accessibilityHidden(true)
                    }
                }

                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        PariAim(size: 9, filled: true, tint: DS.Palette.accent)
                        Text("\(prediction.confidencePercent)%")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.Palette.accent)
                            .monospacedDigit()
                    }

                    Circle()
                        .fill(DS.Palette.textTertiary)
                        .frame(width: 2, height: 2)

                    Text(timeText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isOverdue ? DS.Palette.accentSecondary : DS.Palette.textSecondary)

                    Circle()
                        .fill(DS.Palette.textTertiary)
                        .frame(width: 2, height: 2)

                    Text(prediction.category.displayName.uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .kerning(1.0)
                        .foregroundStyle(DS.Palette.textTertiary)
                }
            }

            Spacer()

            if prediction.isDue {
                ZStack {
                    Circle()
                        .fill(DS.Palette.accentSecondary)
                        .frame(width: 32, height: 32)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DS.Palette.darkSurfacePrimary)
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Palette.textTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DS.Palette.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            isOverdue ? DS.Palette.accentSecondary.opacity(0.4) : DS.Palette.separator,
                            lineWidth: isOverdue ? 1 : 0.5
                        )
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(prediction.isDue ? "Double tap to resolve" : "Double tap for details")
        .accessibilityAddTraits(.isButton)
    }

    private var timeText: String {
        if prediction.isDue {
            return prediction.daysOverdue == 0 ? "Due today" : "\(prediction.daysOverdue)d overdue"
        }
        let d = prediction.daysUntilResolution
        return d == 0 ? "Today" : "\(d)d"
    }

    private var accessibilitySummary: String {
        var parts = [prediction.claim, "\(prediction.confidencePercent) percent confidence", prediction.category.displayName]
        if prediction.isDue {
            parts.append(prediction.daysOverdue == 0 ? "Due today" : "\(prediction.daysOverdue) days overdue")
        } else {
            parts.append("\(prediction.daysUntilResolution) days until resolution")
        }
        return parts.joined(separator: ". ")
    }
}
