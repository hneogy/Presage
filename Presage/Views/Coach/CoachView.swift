import SwiftUI
import SwiftData

struct CoachView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    @Query(filter: #Predicate<Prediction> { $0.outcomeRaw != nil },
           sort: \Prediction.resolvedAt, order: .reverse)
    private var resolved: [Prediction]

    @Query(filter: #Predicate<Prediction> { $0.outcomeRaw == nil })
    private var active: [Prediction]

    @Query(filter: #Predicate<CalibrationSnapshot> { _ in true },
           sort: \CalibrationSnapshot.computedAt, order: .reverse)
    private var snapshots: [CalibrationSnapshot]

    @Query(sort: \CoachMessage.createdAt) private var messages: [CoachMessage]

    @State private var sundayEnabled: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                greetingCard

                weeklyRetroCard

                sundayToggleCard

                if !messages.isEmpty {
                    section("Conversation log") {
                        ForEach(messages.suffix(10).reversed()) { msg in
                            messageBubble(msg)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.insights(colorScheme))
        .navigationTitle("Coach")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: "Apple Foundation Models · On-device")
            Text("Présage Coach")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.5)
        }
    }

    private var greetingCard: some View {
        let dueCount = active.filter { $0.isDue }.count
        return PariCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DS.Palette.accent)
                Text(PariCoach.greeting(activeCount: active.count, dueCount: dueCount))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .lineSpacing(3)
            }
        }
    }

    private var weeklyRetroCard: some View {
        PariCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    WhisperLabel(text: "This week")
                    Spacer()
                    Text("Sunday retrospective")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Palette.textTertiary)
                }
                Text(PariCoach.weeklyRetrospective(predictions: resolved, snapshot: snapshots.first))
                    .font(.system(size: 15))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .lineSpacing(4)
            }
        }
    }

    private var sundayToggleCard: some View {
        PariCard(padding: 16) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(DS.Palette.accentMuted)
                        .frame(width: 36, height: 36)
                    Image(systemName: "bell.badge")
                        .foregroundStyle(DS.Palette.accent)
                        .font(.system(size: 14))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sunday 7pm push")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Palette.textPrimary)
                    Text("Weekly calibration recap.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Palette.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $sundayEnabled)
                    .labelsHidden()
                    .tint(DS.Palette.accent)
                    .onChange(of: sundayEnabled) { _, on in
                        Task {
                            if on {
                                await SundayRetrospectiveScheduler.enable()
                            } else {
                                SundayRetrospectiveScheduler.disable()
                            }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            WhisperLabel(text: title)
            content()
        }
    }

    private func messageBubble(_ msg: CoachMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: msg.role == "coach" ? "sparkles" : "person")
                .foregroundStyle(msg.role == "coach" ? DS.Palette.accent : DS.Palette.textSecondary)
                .font(.system(size: 14))
                .frame(width: 20)
            Text(msg.content)
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.textPrimary)
                .lineSpacing(2)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DS.Palette.surfaceTertiary)
        )
    }
}
