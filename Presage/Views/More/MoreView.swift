import SwiftUI

/// Goal-driven More tab. Sections are organized by user intent ("what
/// am I trying to do?") rather than by feature taxonomy. Every
/// destination is visible — no disclosure, no buried sections.
///
/// Five buckets:
///   1. Sharpen — active calibration practice (Coach, Training, Flashcards, Biases, Question packs)
///   2. AI — interact with LLMs through Présage (Score, AI keys)
///   3. See yourself over time — long-horizon forecasting (Life, Templates, Annual)
///   4. Compare — you vs others (Where you stand, Leaderboard, Public, Twin, Teams)
///   5. Data & Account — manage data + app (CSV, Markdown, Settings)
struct MoreView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                section(
                    title: "Sharpen",
                    blurb: "Active practice — get better at calibrated thinking."
                ) {
                    moreRow(title: "Présage Coach",
                            subtitle: "On-device LLM coach + Sunday retrospectives",
                            icon: "sparkles",
                            tint: DS.Palette.accent) {
                        CoachView()
                    }
                    moreRow(title: "Calibration Training",
                            subtitle: "Pre-resolved questions, instant feedback",
                            icon: "brain.head.profile",
                            tint: DS.Palette.accent) {
                        TrainingView()
                    }
                    moreRow(title: "Flashcards",
                            subtitle: "Anki-style study with calibration",
                            icon: "rectangle.stack",
                            tint: DS.Palette.accentSecondary) {
                        FlashCardView()
                    }
                    moreRow(title: "Cognitive biases",
                            subtitle: "Named biases Présage watches for in your patterns",
                            icon: "brain",
                            tint: DS.Palette.accentSecondary) {
                        BiasEncyclopediaView()
                    }
                    moreRow(title: "Question packs",
                            subtitle: "Curated bundles by theme",
                            icon: "books.vertical",
                            tint: DS.Palette.accent) {
                        QuestionPackStoreView()
                    }
                }

                section(
                    title: "AI",
                    blurb: "Score LLMs against your own calibration."
                ) {
                    moreRow(title: "Score AI answers",
                            subtitle: "Score LLM hallucinations alongside your confidence",
                            icon: "cpu",
                            tint: DS.Palette.accentSecondary) {
                        AIScoringView()
                    }
                    moreRow(title: "AI keys",
                            subtitle: "Add your OpenAI / Anthropic keys for duels",
                            icon: "key.fill",
                            tint: DS.Palette.accent) {
                        AIKeysView()
                    }
                }

                section(
                    title: "See yourself over time",
                    blurb: "Long-horizon forecasts and reports about your year."
                ) {
                    moreRow(title: "Life Forecast",
                            subtitle: "5-year vision in 5 life domains",
                            icon: "scope",
                            tint: DS.Palette.accent) {
                        LifeForecastView()
                    }
                    moreRow(title: "Recurring templates",
                            subtitle: "Auto-spawn predictions on a schedule",
                            icon: "repeat",
                            tint: DS.Palette.accentSecondary) {
                        TemplatesView()
                    }
                    moreRow(title: "Annual report",
                            subtitle: "Printable PDF of your year",
                            icon: "doc.richtext",
                            tint: DS.Palette.accent) {
                        AnnualReportView()
                    }
                }

                section(
                    title: "Compare",
                    blurb: "Where you stand, predictions with others."
                ) {
                    moreRow(title: "Where you stand",
                            subtitle: "Position on the canonical forecasting benchmark",
                            icon: "chart.bar.doc.horizontal",
                            tint: DS.Palette.accent) {
                        PariMedianBenchmarkView()
                    }
                    moreRow(title: "Anonymous standing",
                            subtitle: "Where you sit globally — opt-in",
                            icon: "trophy.fill",
                            tint: DS.Palette.accentSecondary) {
                        LeaderboardView()
                    }
                    moreRow(title: "Public market questions",
                            subtitle: "Mirror Metaculus / Manifold / Polymarket",
                            icon: "globe.europe.africa",
                            tint: DS.Palette.accent) {
                        PublicMarketMirrorView()
                    }
                    moreRow(title: "Twin prediction",
                            subtitle: "Lock in a prediction with a friend",
                            icon: "person.2",
                            tint: DS.Palette.accentSecondary) {
                        TwinPredictionsView()
                    }
                    moreRow(title: "Présage for Teams",
                            subtitle: "Workspace prediction tracking",
                            icon: "person.3.fill",
                            tint: DS.Palette.accent) {
                        TeamsView()
                    }
                }

                section(
                    title: "Help & About",
                    blurb: "Everything about how Présage works, your privacy, and the math."
                ) {
                    moreRow(title: "Knowledge Center",
                            subtitle: "Privacy · accessibility · features · how-to · terms",
                            icon: "book.fill",
                            tint: DS.Palette.accent) {
                        KnowledgeCenterView()
                    }
                }

                section(
                    title: "Data & Account",
                    blurb: "Import, export, and app preferences."
                ) {
                    moreRow(title: "Import from CSV",
                            subtitle: "Fatebook, PredictionBook, spreadsheets",
                            icon: "square.and.arrow.down",
                            tint: DS.Palette.accentSecondary) {
                        CSVImportView()
                    }
                    moreRow(title: "Markdown / Obsidian export",
                            subtitle: "Export full vault as markdown",
                            icon: "doc.text",
                            tint: DS.Palette.accent) {
                        MarkdownExportView()
                    }
                    moreRow(title: "Settings",
                            subtitle: "Theme, sync, notifications, pricing",
                            icon: "gearshape.fill",
                            tint: DS.Palette.textSecondary) {
                        SettingsSheet()
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.more(colorScheme))
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: "Tools & Settings")
            Text("More")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.6)
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        blurb: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                WhisperLabel(text: title)
                Text(blurb)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Palette.textTertiary)
            }
            VStack(spacing: 8) {
                content()
            }
        }
    }

    private func moreRow<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Palette.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Palette.textSecondary)
                        .lineLimit(1)
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
        .buttonStyle(.plain)
    }
}
