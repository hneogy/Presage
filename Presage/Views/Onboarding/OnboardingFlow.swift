import SwiftUI
import SwiftData

/// 60-second onboarding rewrite.
/// Day-3 churn is 72% across all iOS apps. The friction floor of the
/// previous "make 3 predictions" flow was killing retention. This flow
/// gets users to their first prediction in <60 seconds, then defers
/// the rest of the brand pitch to a single tap-through.
struct OnboardingFlow: View {
    @Environment(PariEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var page: OnboardingPage = .hook
    @State private var claim: String = ""
    @State private var confidence: Int = 70
    @State private var aiSuggested: Int? = nil
    @State private var extractorTask: Task<Void, Never>? = nil
    @FocusState private var focused: Bool

    private enum OnboardingPage {
        case hook              // 5-second pitch
        case firstPrediction   // <60-second creation
        case youreIn           // single tap-through
    }

    var body: some View {
        ZStack {
            DS.Palette.surfacePrimary.ignoresSafeArea()

            switch page {
            case .hook:
                hookPage.transition(.opacity)
            case .firstPrediction:
                firstPredictionPage.transition(.opacity)
            case .youreIn:
                youreInPage.transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: page)
    }

    // MARK: - Page 1: Hook (5 seconds, one tap)

    private var hookPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 60)

            Text("Présage")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-1.5)

            VStack(alignment: .leading, spacing: 8) {
                Text("You think you know\nyourself.")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .kerning(-0.6)
                    .lineSpacing(2)
                Text("You don't.")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(DS.Palette.accentSecondary)
                    .kerning(-0.6)
                    .padding(.top, 4)
            }

            Text("One prediction. 60 seconds. Présage measures the gap between what you said and what happened.")
                .font(.system(size: 17))
                .foregroundStyle(DS.Palette.textSecondary)
                .lineSpacing(4)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 8) {
                PariButton("Make my first prediction") {
                    page = .firstPrediction
                }

                Button("Skip onboarding") {
                    finish()
                }
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.textTertiary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Page 2: First Prediction (<60s)

    private var firstPredictionPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — minimal, no progress dots, no whisper
            HStack {
                Button {
                    page = .hook
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(DS.Palette.textSecondary)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 32, height: 32)
                }
                Spacer()
                Button("Skip") { finish() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DS.Palette.textTertiary)
            }
            .padding(.top, 8)
            .padding(.bottom, 32)

            // Single question
            VStack(alignment: .leading, spacing: 8) {
                Text("What do you think will\nhappen this week?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .kerning(-0.5)
                    .lineSpacing(2)
            }

            // Single input
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    PariInput(
                        placeholder: "I will...",
                        text: $claim,
                        isMultiline: true
                    )
                    .focused($focused)
                    .padding(.top, 24)
                    .onChange(of: claim) { _, new in
                        // Debounce — extractor scans the full hedge-word
                        // lexicon, no point re-running it on every
                        // character. 300ms after the user stops typing
                        // is plenty.
                        extractorTask?.cancel()
                        extractorTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(300))
                            guard !Task.isCancelled else { return }
                            aiSuggested = await ConfidenceExtractor.extract(from: new)
                            if let s = aiSuggested { confidence = s }
                        }
                    }

                    if claim.count >= 5 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("How confident?")
                                    .font(.system(size: 11, weight: .semibold))
                                    .kerning(1.6)
                                    .foregroundStyle(DS.Palette.textTertiary)
                                Spacer()
                                if let s = aiSuggested {
                                    Text("Présage guessed \(s)% from your wording")
                                        .font(.system(size: 11))
                                        .foregroundStyle(DS.Palette.accentSecondary)
                                }
                            }
                            ConfidenceDial(confidencePercent: $confidence)
                                .padding(.vertical, 4)
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: claim.count >= 5)
            }
            .scrollDismissesKeyboard(.interactively)

            Spacer()

            VStack(spacing: 6) {
                PariButton("Save · resolves in 7 days") {
                    save()
                }
                .opacity(canSave ? 1 : 0.4)
                .disabled(!canSave)

                Text("That's it. We'll ask you what happened in 7 days.")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Palette.textTertiary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .onAppear {
            focused = true
        }
    }

    // MARK: - Page 3: You're in

    private var youreInPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 60)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(DS.Palette.accent)

            Text("Locked in.")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.6)

            VStack(alignment: .leading, spacing: 14) {
                bullet("In 7 days, Présage will ask you what happened.")
                bullet("You answer first. Your confidence stays hidden.")
                bullet("That gap is what Présage scores.")
            }

            Spacer()

            VStack(spacing: 8) {
                PariButton("Show me Présage") {
                    finish()
                }
                Text("No streaks. No badges. No coach. Just the gap.")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Palette.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(DS.Palette.accent)
                .frame(width: 6, height: 6)
                .padding(.top, 8)
            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(DS.Palette.textSecondary)
                .lineSpacing(2)
        }
    }

    // MARK: - Logic

    private var canSave: Bool {
        claim.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5
    }

    private func save() {
        let resolutionDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

        // Use a concrete, criterion-shaped default so QualityChecker
        // doesn't auto-flag the user's first prediction as vague — that
        // would pollute the wall of shame and confuse early users.
        let trimmedClaim = claim.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultCriteria = "Did the claim '\(trimmedClaim)' actually happen by \(resolutionDate.formatted(.dateTime.month(.abbreviated).day()))?"

        engine.createPrediction(
            claim: trimmedClaim,
            resolutionCriteria: defaultCriteria,
            confidencePercent: confidence,
            resolutionDate: resolutionDate,
            category: .behavior,
            moodTag: nil,
            witnessName: nil,
            in: context
        )
        HapticEngine.shared.resolutionReveal()

        // Schedule the Day-1/3/7 retention push sequence.
        Task { await OnboardingPushScheduler.scheduleRetentionSequence() }

        page = .youreIn
        // Note: RootView treats `predictionCount > 0` as completed-
        // onboarding even if `hasCompletedOnboarding` is false. So a
        // force-quit between save and the "Show me Présage" tap won't
        // re-show onboarding — they'll land in the main app.
    }

    private func finish() {
        hasCompletedOnboarding = true
    }
}
