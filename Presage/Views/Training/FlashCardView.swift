import SwiftUI
import SwiftData

/// Anki-with-uncertainty: every flashcard review requires a confidence
/// percentage on whether you'll get the answer right BEFORE seeing it.
/// Calibration training that doubles as study tool.
struct FlashCardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \FlashCard.lastReviewedAt) private var cards: [FlashCard]

    @State private var currentIndex: Int = 0
    @State private var phase: ReviewPhase = .predict
    @State private var confidencePercent: Int = 70
    @State private var revealedAnswer: String? = nil
    @State private var showingAddCard: Bool = false

    enum ReviewPhase {
        case predict     // user sets confidence
        case answer      // user thinks of answer
        case reveal      // show actual answer + score
    }

    private var currentCard: FlashCard? {
        guard !cards.isEmpty else { return nil }
        return cards[currentIndex % cards.count]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let card = currentCard {
                    cardView(card)
                } else {
                    PariEmptyState(
                        icon: "rectangle.stack.badge.plus",
                        title: "No cards yet",
                        message: "Add cards to study with confidence calibration.",
                        actionTitle: "Add card"
                    ) {
                        showingAddCard = true
                    }
                    .padding(.top, 60)
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.predict(colorScheme))
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddCard = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(DS.Palette.accent)
                }
            }
        }
        .sheet(isPresented: $showingAddCard) {
            FlashCardEditor()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            WhisperLabel(text: "Anki + Uncertainty")
            Text("Study with calibration")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.4)
        }
    }

    private func cardView(_ card: FlashCard) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            PariCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        WhisperLabel(text: card.deckName)
                        Spacer()
                        Text("\(card.reviewCount) reviews")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(DS.Palette.textTertiary)
                            .monospacedDigit()
                    }
                    Text(card.front)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(DS.Palette.textPrimary)
                        .lineSpacing(4)

                    if phase == .reveal {
                        Divider().background(DS.Palette.separator)
                        Text(card.back)
                            .font(.system(size: 20))
                            .foregroundStyle(DS.Palette.accent)
                            .lineSpacing(4)
                    }
                }
            }

            switch phase {
            case .predict:
                VStack(alignment: .leading, spacing: 12) {
                    WhisperLabel(text: "How likely will you get it right?")
                    ConfidenceDial(confidencePercent: $confidencePercent)
                        .padding(.vertical, 8)
                    PariButton("Show card") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            phase = .answer
                        }
                    }
                }
            case .answer:
                VStack(alignment: .leading, spacing: 12) {
                    Text("Think of your answer, then reveal.")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.Palette.textSecondary)
                    PariButton("Reveal answer", style: .secondary) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            phase = .reveal
                        }
                    }
                }
            case .reveal:
                VStack(alignment: .leading, spacing: 12) {
                    WhisperLabel(text: "Did you get it right?")
                    HStack(spacing: 10) {
                        gradeButton(label: "Right", correct: true, card: card)
                        gradeButton(label: "Wrong", correct: false, card: card)
                    }
                }
            }
        }
    }

    private func gradeButton(label: String, correct: Bool, card: FlashCard) -> some View {
        Button {
            grade(card: card, correct: correct)
        } label: {
            Text(label)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(correct ? DS.Palette.darkSurfacePrimary : DS.Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule(style: .continuous)
                        .fill(correct ? DS.Palette.accent : DS.Palette.surfaceTertiary)
                )
        }
        .buttonStyle(.plain)
    }

    private func grade(card: FlashCard, correct: Bool) {
        let brier = ScoringEngine.brierScore(confidencePercent: confidencePercent, outcome: correct)
        card.lastConfidencePercent = confidencePercent
        card.lastWasCorrect = correct
        card.lastReviewedAt = .now
        card.reviewCount += 1
        if let avg = card.averageBrierScore {
            card.averageBrierScore = (avg * Double(card.reviewCount - 1) + brier) / Double(card.reviewCount)
        } else {
            card.averageBrierScore = brier
        }
        try? context.save()
        HapticEngine.shared.resolutionReveal()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentIndex += 1
            phase = .predict
            confidencePercent = 70
        }
    }
}

// MARK: - Editor

struct FlashCardEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var front: String = ""
    @State private var back: String = ""
    @State private var deckName: String = "Default"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        WhisperLabel(text: "Question / Front")
                        PariInput(placeholder: "What is the capital of...?", text: $front, isMultiline: true)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        WhisperLabel(text: "Answer / Back")
                        PariInput(placeholder: "The correct answer", text: $back, isMultiline: true)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        WhisperLabel(text: "Deck")
                        PariInput(placeholder: "Default", text: $deckName)
                    }
                    PariButton("Add card") {
                        let card = FlashCard(front: front, back: back, deckName: deckName)
                        context.insert(card)
                        try? context.save()
                        dismiss()
                    }
                    .opacity(canSave ? 1 : 0.4)
                    .disabled(!canSave)
                }
                .padding(20)
            }
            .background(DS.Palette.surfacePrimary)
            .navigationTitle("New card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Palette.textSecondary)
                }
            }
        }
    }

    private var canSave: Bool {
        !front.isEmpty && !back.isEmpty
    }
}
