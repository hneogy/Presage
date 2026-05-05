import SwiftUI
import SwiftData

/// "Présage for AI" — score an LLM's confident answer alongside your own
/// confidence in it being correct. When you later verify, both you and
/// the AI get a Brier score. Aggregates into the world's first
/// crowd-sourced LLM hallucination calibration index.
struct AIScoringView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    @State private var question: String = ""
    @State private var aiAnswer: String = ""
    @State private var aiModel: AIModel = .claude46
    @State private var userConfidence: Int = 70
    @State private var aiSelfConfidence: Int? = nil
    @State private var saveErrorMessage: String? = nil

    @Query(sort: \AIPrediction.createdAt, order: .reverse)
    private var aiPredictions: [AIPrediction]

    private var openItems: [AIPrediction] { aiPredictions.filter { $0.actualWasCorrect == nil } }
    private var resolvedItems: [AIPrediction] { aiPredictions.filter { $0.actualWasCorrect != nil } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                statsBar

                creationCard

                if !openItems.isEmpty {
                    section("Awaiting verification", count: openItems.count) {
                        ForEach(openItems) { pred in
                            aiPredictionCard(pred, resolved: false)
                        }
                    }
                }

                if !resolvedItems.isEmpty {
                    section("Resolved", count: resolvedItems.count) {
                        ForEach(resolvedItems.prefix(10)) { pred in
                            aiPredictionCard(pred, resolved: true)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.predict(colorScheme))
        .navigationTitle("Présage for AI")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn't save", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: "Score the model")
            Text("Présage for AI")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.5)
            Text("Paste an LLM answer + your confidence that it's correct. Verify later. Both you and the AI get scored.")
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.textSecondary)
                .lineSpacing(2)
                .padding(.top, 4)
        }
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            statTile("You", value: aggregateBrier(\.userBrierScore))
            statTile("\(aiModel.displayName)", value: aggregateBrier(\.aiBrierScore), coral: true)
        }
    }

    private func statTile(_ label: String, value: String, coral: Bool = false) -> some View {
        PariCard(padding: 14) {
            VStack(alignment: .leading, spacing: 4) {
                WhisperLabel(text: label)
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(coral ? DS.Palette.accentSecondary : DS.Palette.accent)
                    .monospacedDigit()
            }
        }
    }

    private func aggregateBrier(_ keyPath: KeyPath<AIPrediction, Double?>) -> String {
        let scores = resolvedItems.compactMap { $0[keyPath: keyPath] }
        guard !scores.isEmpty else { return "—" }
        return PariFormat.brier(scores.reduce(0, +) / Double(scores.count))
    }

    private var creationCard: some View {
        PariCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Score a new AI answer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Palette.textPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    WhisperLabel(text: "Question you asked")
                    PariInput(placeholder: "What did you ask the model?", text: $question, isMultiline: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    WhisperLabel(text: "Model's answer")
                    PariInput(placeholder: "Paste the model's reply", text: $aiAnswer, isMultiline: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    WhisperLabel(text: "Model")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(AIModel.allCases, id: \.self) { m in
                                PariChip(label: m.displayName, isSelected: aiModel == m) {
                                    aiModel = m
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    WhisperLabel(text: "Your confidence the answer is correct")
                    ConfidenceDial(confidencePercent: $userConfidence)
                        .padding(.vertical, 8)
                }

                PariButton("Save") {
                    save()
                }
                .opacity(canSave ? 1 : 0.4)
                .disabled(!canSave)
            }
        }
    }

    private func aiPredictionCard(_ pred: AIPrediction, resolved: Bool) -> some View {
        PariCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(pred.aiModel.displayName.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(DS.Palette.accentSecondary)
                    Spacer()
                    if resolved, let correct = pred.actualWasCorrect {
                        Text(correct ? "CORRECT" : "WRONG")
                            .font(.system(size: 11, weight: .semibold))
                            .kerning(1.5)
                            .foregroundStyle(correct ? DS.Palette.accent : DS.Palette.accentSecondary)
                    }
                }

                Text(pred.question)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .lineLimit(3)

                Text(pred.aiAnswer)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Palette.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Text("You: \(pred.userConfidencePercent)%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.Palette.accent)
                    if let aiConf = pred.aiSelfReportedConfidence {
                        Text("AI: \(aiConf)%")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.Palette.accentSecondary)
                    }
                }

                if !resolved {
                    HStack(spacing: 10) {
                        Button("Mark correct") { resolve(pred, correct: true) }
                            .buttonStyle(.bordered)
                            .tint(DS.Palette.accent)
                        Button("Mark wrong") { resolve(pred, correct: false) }
                            .buttonStyle(.bordered)
                            .tint(DS.Palette.accentSecondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func section<C: View>(_ title: String, count: Int, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(DS.Typo.titleLarge)
                    .foregroundStyle(DS.Palette.textPrimary)
                Text("\(count)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Palette.accentSecondary)
            }
            content()
        }
    }

    private var canSave: Bool {
        question.count >= 5 && aiAnswer.count >= 3
    }

    private func save() {
        let pred = AIPrediction(
            question: question,
            aiAnswer: aiAnswer,
            aiModel: aiModel,
            userConfidence: userConfidence
        )
        context.insert(pred)
        do {
            try context.save()
        } catch {
            // Roll back the insert so the @Query doesn't surface a
            // half-saved record.
            context.delete(pred)
            saveErrorMessage = "Couldn't save this AI prediction: \(error.localizedDescription)"
            return
        }
        question = ""
        aiAnswer = ""
        userConfidence = 70
        HapticEngine.shared.resolutionReveal()
    }

    private func resolve(_ pred: AIPrediction, correct: Bool) {
        pred.actualWasCorrect = correct
        pred.resolvedAt = .now
        pred.userBrierScore = ScoringEngine.brierScore(
            confidencePercent: pred.userConfidencePercent,
            outcome: correct
        )
        if let aiConf = pred.aiSelfReportedConfidence {
            pred.aiBrierScore = ScoringEngine.brierScore(
                confidencePercent: aiConf,
                outcome: correct
            )
        }
        do {
            try context.save()
        } catch {
            saveErrorMessage = "Couldn't record the resolution: \(error.localizedDescription)"
            return
        }
        HapticEngine.shared.resolutionReveal()
    }
}
