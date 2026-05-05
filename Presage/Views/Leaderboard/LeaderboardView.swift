import SwiftUI
import SwiftData

struct LeaderboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    // The singleton is `@Observable`; binding to it ensures the view
    // reacts to mutations performed elsewhere (e.g., a deep-link or
    // intent toggling opt-in state).
    @Bindable private var leaderboard = LeaderboardService.shared

    @Query(filter: #Predicate<CalibrationSnapshot> { _ in true },
           sort: \CalibrationSnapshot.computedAt, order: .reverse)
    private var snapshots: [CalibrationSnapshot]

    private var brier: Double? { snapshots.first?.brierScore }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if !leaderboard.isOptedIn {
                    optInCard
                } else if let b = brier {
                    standingCard(brier: b)
                    privacyExplainer
                } else {
                    PariCard {
                        Text("Resolve at least one prediction to see your standing.")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Palette.textSecondary)
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.insights(colorScheme))
        .navigationTitle("Standing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: "Anonymous · opt-in")
            Text("Where you stand")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.4)
        }
    }

    private var optInCard: some View {
        PariCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("See your global percentile.")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.Palette.textPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Only your Brier number is shared.", systemImage: "lock.shield")
                    Label("No claims, no criteria, no personal data.", systemImage: "eye.slash")
                    Label("You can opt out at any time.", systemImage: "arrow.uturn.left")
                }
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.textSecondary)

                PariButton("Opt in") {
                    leaderboard.isOptedIn = true
                    if let b = brier {
                        Task { await leaderboard.submit(brier: b) }
                    }
                }
            }
        }
    }

    private func standingCard(brier b: Double) -> some View {
        PariCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        WhisperLabel(text: "Pseudonym")
                        Text(leaderboard.pseudonym)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DS.Palette.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        WhisperLabel(text: "Percentile")
                        Text("\(leaderboard.percentile(for: b))")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Palette.accentSecondary)
                            .monospacedDigit()
                    }
                }

                Divider().background(DS.Palette.separator)

                HStack {
                    Text(leaderboard.projectedRank(for: b))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Palette.accent)
                    Spacer()
                    Text("Brier \(PariFormat.brier(b))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(DS.Palette.textSecondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var privacyExplainer: some View {
        Text("The leaderboard is purely anonymous: only your Brier score and your random pseudonym ever leave the device. Tap Settings → Sync → Leaderboard to opt out at any time.")
            .font(.system(size: 11))
            .foregroundStyle(DS.Palette.textTertiary)
            .lineSpacing(3)
    }
}
