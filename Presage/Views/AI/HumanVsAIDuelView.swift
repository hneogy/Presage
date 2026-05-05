import SwiftUI
import SwiftData

struct HumanVsAIDuelView: View {
    let prediction: Prediction
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var aiModel: AIModel = .claude46
    @State private var loading = false
    @State private var aiConfidence: Int? = nil
    @State private var aiReasoning: String? = nil
    @State private var saved = false
    @State private var lastError: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                claimCard

                modelPicker

                if let conf = aiConfidence {
                    aiResultCard(conf)
                } else if let err = lastError {
                    errorCard(err)
                } else {
                    PariButton(loading ? "Asking…" : "Ask the model") {
                        ask()
                    }
                    .disabled(loading)
                }

                explainerCard
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.predict(colorScheme))
        .navigationTitle("Human vs AI")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: "Duel")
            Text("Score the model with you")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.4)
        }
    }

    private var claimCard: some View {
        PariCard {
            VStack(alignment: .leading, spacing: 8) {
                WhisperLabel(text: "Your prediction")
                Text(prediction.claim)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Palette.textPrimary)
                Text("You said \(prediction.confidencePercent)%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Palette.accent)
            }
        }
    }

    private var modelPicker: some View {
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

    private func aiResultCard(_ conf: Int) -> some View {
        PariCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(aiModel.displayName.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(DS.Palette.accentSecondary)
                    Spacer()
                    Text("\(conf)%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Palette.accentSecondary)
                        .monospacedDigit()
                }
                if let reasoning = aiReasoning {
                    Text(reasoning)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Palette.textSecondary)
                        .lineSpacing(2)
                }

                if !saved {
                    PariButton("Lock in this duel", style: .secondary) {
                        let duel = DuelPrediction(predictionID: prediction.id, aiModel: aiModel,
                                                  aiConfidence: conf, aiReasoning: aiReasoning)
                        context.insert(duel)
                        if PariPersistence.attemptSave(context, label: "lock in duel") {
                            saved = true
                            HapticEngine.shared.resolutionReveal()
                        } else {
                            // Roll back so the @Query doesn't surface a
                            // half-saved duel and the user can retry.
                            context.delete(duel)
                            lastError = "Couldn't save the duel. Try again."
                        }
                    }
                } else {
                    Text("Locked. Both you and \(aiModel.displayName) will be scored when this resolves.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Palette.accent)
                }
            }
        }
    }

    private var explainerCard: some View {
        Text("Présage sends only the claim text to your chosen model — no other history. Use your own API key in Settings → AI to enable real model calls.")
            .font(.system(size: 11))
            .foregroundStyle(DS.Palette.textTertiary)
            .lineSpacing(2)
    }

    private func ask() {
        loading = true
        lastError = nil
        Task {
            do {
                let result = try await AILLMBridge.shared.askForConfidence(
                    claim: prediction.claim,
                    criteria: prediction.resolutionCriteria,
                    model: aiModel
                )
                aiConfidence = result.confidence
                aiReasoning = result.reasoning
                lastError = nil
            } catch {
                lastError = "Couldn't reach \(aiModel.displayName). Check your API key in Settings → AI, or try again."
            }
            loading = false
        }
    }

    private func errorCard(_ message: String) -> some View {
        PariCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DS.Palette.accentSecondary)
                    Text("Couldn't ask the model")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Palette.textPrimary)
                }
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Palette.textSecondary)
                    .lineSpacing(2)
                PariButton("Try again", style: .secondary) {
                    ask()
                }
                .disabled(loading)
            }
        }
    }
}
