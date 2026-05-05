import SwiftUI
import SwiftData

/// Curated bundles of pre-resolved training questions. All packs are
/// free — Présage ships as a free app, no gating.
struct QuestionPackStoreView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    private let packs: [QuestionPack] = [
        QuestionPack(id: "history-2024", name: "World History 2024", icon: "books.vertical", count: 100, theme: "History"),
        QuestionPack(id: "science-fundamentals", name: "Science Fundamentals", icon: "atom", count: 100, theme: "Science"),
        QuestionPack(id: "sports-trivia", name: "Sports Calibration", icon: "sportscourt", count: 75, theme: "Sports"),
        QuestionPack(id: "ai-forecasts", name: "AI Forecasts 2026", icon: "cpu", count: 50, theme: "Tech"),
        QuestionPack(id: "geo-extreme", name: "Geography Extreme", icon: "globe", count: 80, theme: "Geography"),
        QuestionPack(id: "climate-2030", name: "Climate Forecasts 2030", icon: "thermometer", count: 60, theme: "Climate"),
        QuestionPack(id: "mindshare-2026", name: "Mindshare Markets", icon: "sparkles.tv", count: 40, theme: "Creator economy"),
        QuestionPack(id: "macro-2026", name: "Macro 2026", icon: "chart.line.uptrend.xyaxis", count: 60, theme: "Markets"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ForEach(packs) { pack in
                    NavigationLink {
                        TrainingView()
                            .navigationTitle(pack.name)
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        packCard(pack)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(pack.name), \(pack.count) questions, \(pack.theme)")
                    .accessibilityHint("Opens the training session for this pack")
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.insights(colorScheme))
        .navigationTitle("Question packs")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: "Curated practice")
            Text("Question packs")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.4)
            Text("Curated bundles of pre-resolved questions to train on. Track your accuracy across themes.")
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.textSecondary)
                .lineSpacing(2)
                .padding(.top, 4)
        }
    }

    private func packCard(_ pack: QuestionPack) -> some View {
        PariCard {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DS.Palette.accentMuted)
                        .frame(width: 48, height: 48)
                    Image(systemName: pack.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DS.Palette.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Palette.textPrimary)
                    HStack(spacing: 8) {
                        Text("\(pack.count) questions")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DS.Palette.textSecondary)
                            .monospacedDigit()
                        Circle().fill(DS.Palette.textTertiary).frame(width: 2, height: 2)
                        Text(pack.theme)
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Palette.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(DS.Palette.textTertiary)
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    }

    struct QuestionPack: Identifiable {
        let id: String
        let name: String
        let icon: String
        let count: Int
        let theme: String
    }
}
