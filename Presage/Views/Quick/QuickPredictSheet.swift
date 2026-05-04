import SwiftUI
import SwiftData

/// 2-tap prediction creation. Daylio-style entry friction.
/// Tap +, tap claim → confidence → save. Defaults handle the rest.
struct QuickPredictSheet: View {
    @Environment(PariEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var claim: String = ""
    @State private var confidence: Int = 70
    @State private var aiSuggestedConfidence: Int? = nil
    @State private var extractorTask: Task<Void, Never>? = nil
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                headerStrip

                ClaimInput(text: $claim)
                    .focused($focused)
                    .onChange(of: claim) { _, new in
                        extractorTask?.cancel()
                        extractorTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(300))
                            guard !Task.isCancelled else { return }
                            aiSuggestedConfidence = await ConfidenceExtractor.extract(from: new)
                        }
                    }

                if let suggested = aiSuggestedConfidence, suggested != confidence {
                    aiSuggestionRow(suggested)
                }

                Text("Confidence")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.6)
                    .foregroundStyle(DS.Palette.textTertiary)
                    .textCase(.uppercase)

                ConfidenceDial(confidencePercent: $confidence)

                Spacer()

                PariButton("Save · resolves in 1 week") {
                    save()
                }
                .opacity(canSave ? 1 : 0.4)
                .disabled(!canSave)
            }
            .padding(20)
            .background(DS.Palette.surfacePrimary)
            .navigationTitle("Quick predict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Palette.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(300))
                            engine.showNewPrediction = true
                        }
                    } label: {
                        Text("Full form")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DS.Palette.accent)
                    }
                }
            }
            .onAppear {
                focused = true
            }
        }
    }

    private var headerStrip: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(DS.Palette.accentSecondary)
            Text("Two taps. Defaults handle the rest.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.Palette.textSecondary)
        }
        .padding(.bottom, 4)
    }

    private func aiSuggestionRow(_ suggested: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                confidence = suggested
            }
            HapticEngine.shared.confidenceTick(at: suggested)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                Text("Présage suggests \(suggested)% based on how you wrote it")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.Palette.textPrimary)
                Spacer()
                Text("Tap to use")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Palette.accent)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DS.Palette.accentMuted)
            )
            .foregroundStyle(DS.Palette.accent)
        }
        .buttonStyle(.plain)
    }

    private var canSave: Bool {
        claim.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5
    }

    private func save() {
        let resolutionDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        let trimmed = claim.trimmingCharacters(in: .whitespacesAndNewlines)
        // Concrete, criterion-shaped default so QualityChecker doesn't
        // flag this as vague — would otherwise pollute the wall of shame.
        let defaultCriteria = "Did the claim '\(trimmed)' actually happen by \(resolutionDate.formatted(.dateTime.month(.abbreviated).day()))?"

        engine.createPrediction(
            claim: trimmed,
            resolutionCriteria: defaultCriteria,
            confidencePercent: confidence,
            resolutionDate: resolutionDate,
            category: .behavior,
            moodTag: nil,
            witnessName: nil,
            in: context
        )
        HapticEngine.shared.resolutionReveal()
        dismiss()
    }
}
