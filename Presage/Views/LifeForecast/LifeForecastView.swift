import SwiftUI
import SwiftData

struct LifeForecastView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \LifeForecast.createdAt) private var forecasts: [LifeForecast]
    @State private var showingEditor = false
    @State private var editingDomain: LifeDomain = .career

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if forecasts.isEmpty {
                    emptyState
                } else {
                    ForEach(LifeDomain.allCases, id: \.self) { domain in
                        if let f = forecasts.first(where: { $0.domain == domain }) {
                            forecastCard(f)
                        } else {
                            createCard(domain)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.insights(colorScheme))
        .navigationTitle("Life Forecast")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditor) {
            LifeForecastEditor(domain: editingDomain)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: "5-year vision")
            Text("Life Forecast")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.5)
            Text("Write a vision in 5 domains. Each milestone becomes a resolvable prediction. Présage scores your long-horizon trajectory.")
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.textSecondary)
                .lineSpacing(2)
                .padding(.top, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ForEach(LifeDomain.allCases, id: \.self) { d in
                createCard(d)
            }
        }
    }

    private func createCard(_ d: LifeDomain) -> some View {
        Button {
            editingDomain = d
            showingEditor = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DS.Palette.accentMuted)
                        .frame(width: 44, height: 44)
                    Image(systemName: d.sfSymbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DS.Palette.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(d.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Palette.textPrimary)
                    Text("Tap to write your 5-year vision")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(DS.Palette.accentSecondary)
                    .font(.system(size: 18))
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
        .buttonStyle(.plain)
    }

    private func forecastCard(_ f: LifeForecast) -> some View {
        PariCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: f.domain.sfSymbol)
                        .foregroundStyle(DS.Palette.accent)
                    Text(f.domain.displayName.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(DS.Palette.accent)
                    Spacer()
                    Text("\(f.horizonYears)y")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.Palette.accentSecondary)
                }
                Text(f.visionStatement)
                    .font(.system(size: 15))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .lineSpacing(3)
                Text("\(f.milestones.count) milestone\(f.milestones.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Palette.textTertiary)
            }
        }
    }
}

struct LifeForecastEditor: View {
    let domain: LifeDomain
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var vision = ""
    @State private var horizonYears: Int = 5

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: domain.sfSymbol)
                            .foregroundStyle(DS.Palette.accent)
                        Text(domain.displayName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(DS.Palette.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        WhisperLabel(text: "5-year vision")
                        PariInput(placeholder: "In 5 years I will...", text: $vision, isMultiline: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        WhisperLabel(text: "Horizon")
                        HStack(spacing: 8) {
                            ForEach([1, 3, 5], id: \.self) { y in
                                PariChip(label: "\(y)y", isSelected: horizonYears == y) {
                                    horizonYears = y
                                }
                            }
                        }
                    }

                    PariButton("Save vision") {
                        let f = LifeForecast(domain: domain, horizonYears: horizonYears, vision: vision)
                        context.insert(f)
                        if PariPersistence.attemptSave(context, label: "save life forecast") {
                            dismiss()
                        } else {
                            // Roll back so the user can retry without
                            // an orphan vision attached to the context.
                            context.delete(f)
                        }
                    }
                    .opacity(canSave ? 1 : 0.4)
                    .disabled(!canSave)

                    if !canSave {
                        Text("Write at least 10 characters — vague visions are hard to score against in five years.")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Palette.textTertiary)
                    }
                }
                .padding(20)
            }
            .background(DS.Palette.surfacePrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Palette.textSecondary)
                }
            }
        }
    }
    private var canSave: Bool { vision.count >= 10 }
}
