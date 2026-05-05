import SwiftUI
import SwiftData

/// Calibration training mode — pre-resolved questions with immediate
/// feedback. The single biggest competitive gap closed: users get
/// calibration insight on day 1 instead of waiting weeks.
struct TrainingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentQuestion: TrainingQuestion?
    @State private var confidencePercent: Int = 70
    @State private var userAnswerYes: Bool? = nil
    @State private var revealedQuestion: TrainingQuestion? = nil

    @Query(filter: #Predicate<TrainingQuestion> { $0.userBrierScore != nil })
    private var answered: [TrainingQuestion]

    private var sessionScore: Double? {
        guard !answered.isEmpty else { return nil }
        let total = answered.compactMap { $0.userBrierScore }.reduce(0, +)
        return total / Double(answered.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let q = currentQuestion {
                    questionCard(q)
                    answerControls(q)
                } else if revealedQuestion != nil {
                    // Intentionally empty — the revealCard below carries
                    // the screen during this transitional state.
                    Color.clear.frame(height: 0)
                } else {
                    PariEmptyState(
                        icon: "checkmark.seal",
                        title: "All caught up",
                        message: "You've answered every question in the starter pack. New packs coming soon."
                    )
                    .padding(.top, 60)
                }

                if let revealed = revealedQuestion {
                    revealCard(revealed)
                    PariButton("Next question") {
                        revealedQuestion = nil
                        loadNext()
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.predict(colorScheme))
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            TrainingPack.seedIfNeeded(in: context)
            if currentQuestion == nil && revealedQuestion == nil {
                loadNext()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                WhisperLabel(text: "Calibration Practice")
                Text("Train your gut")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .kerning(-0.4)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                WhisperLabel(text: "Session")
                if let score = sessionScore {
                    Text(PariFormat.brier(score))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Palette.accent)
                        .monospacedDigit()
                } else {
                    Text("—")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Palette.textTertiary)
                }
            }
        }
    }

    private func questionCard(_ question: TrainingQuestion) -> some View {
        PariCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(question.topic.displayName.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(DS.Palette.accentSecondary)
                    Spacer()
                    Text("Q\(answered.count + 1)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.Palette.textTertiary)
                        .monospacedDigit()
                }

                Text(question.prompt)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .lineSpacing(4)
            }
        }
    }

    private func answerControls(_ question: TrainingQuestion) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                WhisperLabel(text: "Your answer")
                HStack(spacing: 10) {
                    answerButton("True", isYes: true)
                    answerButton("False", isYes: false)
                }
            }

            if userAnswerYes != nil {
                VStack(alignment: .leading, spacing: 12) {
                    WhisperLabel(text: "How confident?")
                    ConfidenceDial(confidencePercent: $confidencePercent)
                        .padding(.vertical, 8)
                }
                .transition(.opacity)

                PariButton("Reveal answer") {
                    submit(question)
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: userAnswerYes != nil)
    }

    private func answerButton(_ label: String, isYes: Bool) -> some View {
        let isSelected = userAnswerYes == isYes
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                userAnswerYes = isYes
            }
            HapticService.medium()
        } label: {
            Text(label)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? DS.Palette.darkSurfacePrimary : DS.Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? DS.Palette.accent : DS.Palette.surfaceTertiary)
                )
        }
        .buttonStyle(.plain)
    }

    private func revealCard(_ question: TrainingQuestion) -> some View {
        PariCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: wasCorrect(question) ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(wasCorrect(question) ? DS.Palette.accent : DS.Palette.accentSecondary)
                        .font(.system(size: 22, weight: .semibold))
                    Text(wasCorrect(question) ? "Correct" : "Wrong")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(wasCorrect(question) ? DS.Palette.accent : DS.Palette.accentSecondary)
                    Spacer()
                    if let brier = question.userBrierScore {
                        Text("Brier \(PariFormat.brier(brier))")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.Palette.textSecondary)
                            .monospacedDigit()
                    }
                }

                Text(question.correctAnswer)
                    .font(.system(size: 16))
                    .foregroundStyle(DS.Palette.textSecondary)
                    .lineSpacing(2)

                if let confidence = question.userConfidencePercent {
                    Divider().background(DS.Palette.separator)
                    HStack {
                        Text("You said \(question.userAnswerYes == true ? "TRUE" : "FALSE") at \(confidence)%")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Palette.textTertiary)
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Logic

    private func loadNext() {
        currentQuestion = TrainingPack.nextUnanswered(in: context)
        userAnswerYes = nil
        confidencePercent = 70
    }

    private func submit(_ question: TrainingQuestion) {
        guard let answer = userAnswerYes else { return }
        // Capture the prior state so we can roll back if persistence
        // fails — without this the user sees a "reviewed" UI for a
        // training answer that never made it to disk.
        let priorAnsweredAt = question.userAnsweredAt
        let priorAnswerYes = question.userAnswerYes
        let priorConfidence = question.userConfidencePercent
        let priorBrier = question.userBrierScore

        question.userAnsweredAt = .now
        question.userAnswerYes = answer
        question.userConfidencePercent = confidencePercent
        let wasYes = answer == question.isYesAnswer
        question.userBrierScore = ScoringEngine.brierScore(
            confidencePercent: confidencePercent,
            outcome: wasYes
        )
        guard PariPersistence.attemptSave(context, label: "training answer") else {
            question.userAnsweredAt = priorAnsweredAt
            question.userAnswerYes = priorAnswerYes
            question.userConfidencePercent = priorConfidence
            question.userBrierScore = priorBrier
            return
        }

        HapticEngine.shared.resolutionReveal()
        revealedQuestion = question
        currentQuestion = nil
    }

    private func wasCorrect(_ question: TrainingQuestion) -> Bool {
        question.userAnswerYes == question.isYesAnswer
    }
}
