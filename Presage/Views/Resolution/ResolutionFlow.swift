import SwiftUI
import SwiftData

struct ResolutionFlow: View {
    @Environment(PariEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let prediction: Prediction

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: ResolutionStep = .prompt
    @State private var selectedOutcome: ResolutionOutcome?
    @State private var wasFudged = false
    @State private var showFudgeOptions = false
    @State private var revealProgress: CGFloat = 0
    @State private var showShareSheet = false

    private enum ResolutionStep {
        case prompt
        case reveal
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Palette.surfacePrimary.ignoresSafeArea()

                switch step {
                case .prompt:
                    promptPhase
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                case .reveal:
                    revealPhase
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: step)
            .sheet(isPresented: $showShareSheet) {
                ShareCardSheet(prediction: prediction, overallBrier: nil)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip for now") { dismiss() }
                        .font(DS.Typo.subhead)
                        .foregroundStyle(DS.Palette.textTertiary)
                }
            }
        }
    }

    // MARK: - Phase 1: Prompt

    private var promptPhase: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 24)

                VStack(spacing: 8) {
                    WhisperLabel(text: "Resolve")
                    Text("Did this happen?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(DS.Palette.textPrimary)
                        .kerning(-0.5)
                }
                .frame(maxWidth: .infinity)

                claimCard
                resolutionButtons

                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }

    private var claimCard: some View {
        PariCard {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                Text(prediction.claim)
                    .font(DS.Typo.titleLarge)
                    .foregroundStyle(DS.Palette.textPrimary)

                PariDivider()

                HStack(spacing: DS.Space.sm) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.Palette.textTertiary)
                    Text("What counts as yes:")
                        .font(DS.Typo.footnote)
                        .foregroundStyle(DS.Palette.textTertiary)
                }

                Text(prediction.resolutionCriteria)
                    .font(DS.Typo.body)
                    .foregroundStyle(DS.Palette.textSecondary)
            }
        }
    }

    private var resolutionButtons: some View {
        VStack(spacing: DS.Space.md) {
            PariButton("Yes, this happened", style: .secondary, icon: "checkmark.circle", iconColor: DS.Palette.semanticYes) {
                resolveWith(.yes, fudged: false)
            }

            PariButton("No, this did not happen", style: .secondary, icon: "xmark.circle", iconColor: DS.Palette.semanticNo) {
                resolveWith(.no, fudged: false)
            }

            Spacer().frame(height: DS.Space.xs)

            PariButton("It's ambiguous", style: .ghost, icon: "questionmark.circle") {
                resolveWith(.ambiguous, fudged: false)
            }

            Button {
                withAnimation(DS.Motion.stateAnimation) {
                    showFudgeOptions.toggle()
                }
            } label: {
                HStack(spacing: DS.Space.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 14))
                    Text("I want to say yes, but...")
                }
                .font(DS.Typo.subhead)
                .foregroundStyle(DS.Palette.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .accessibilityLabel("I want to say yes, but it's a stretch")
            .accessibilityHint("Opens an honesty check before resolving as ambiguous")

            if showFudgeOptions {
                fudgeOptionsView
            }
        }
    }

    private var fudgeOptionsView: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            Text("Be honest with yourself. Re-read the criteria above.")
                .font(DS.Typo.callout)
                .foregroundStyle(DS.Palette.textSecondary)
                .italic()

            PariButton("It genuinely happened — I was being cautious", style: .secondary) {
                resolveWith(.yes, fudged: false)
            }

            PariButton("It mostly happened but didn't meet my criteria", style: .secondary) {
                resolveWith(.no, fudged: true)
            }

            PariButton("I need to think about this more", style: .ghost) {
                dismiss()
            }
        }
        .padding(DS.Space.base)
        .background(DS.Palette.surfaceTertiary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Phase 2: Reveal

    private var revealPhase: some View {
        ScrollView {
            VStack(spacing: DS.Space.lg) {
                Spacer().frame(height: DS.Space.xxl)

                outcomeCard

                PariDivider()

                scoreImpactCard

                calibrationContext

                if prediction.witnessName != nil {
                    PariButton("Ask witness to confirm", style: .secondary, icon: "person.wave.2") {
                        WitnessShareService.presentShareSheet(for: prediction)
                    }
                }

                PariButton("Share this resolution", style: .secondary, icon: "square.and.arrow.up") {
                    showShareSheet = true
                }

                PariButton("Done") {
                    dismiss()
                }

                PariButton("Make another prediction", style: .ghost) {
                    dismiss()
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))
                        engine.showNewPrediction = true
                    }
                }
            }
            .padding(.horizontal, DS.Space.base)
            .padding(.bottom, DS.Space.xxxxl)
        }
    }

    private var outcomeCard: some View {
        PariCard {
            VStack(spacing: DS.Space.base) {
                outcomeBanner

                HStack(spacing: DS.Space.xl) {
                    VStack(spacing: DS.Space.xs) {
                        Text("You said")
                            .font(DS.Typo.footnote)
                            .foregroundStyle(DS.Palette.textTertiary)
                        Text("\(Int(Double(prediction.confidencePercent) * revealProgress))% yes")
                            .font(DS.Typo.titleLarge)
                            .foregroundStyle(DS.Palette.textPrimary)
                            .contentTransition(.numericText())
                    }

                    VStack(spacing: DS.Space.xs) {
                        Text("Reality")
                            .font(DS.Typo.footnote)
                            .foregroundStyle(DS.Palette.textTertiary)
                        Text(outcomeLabel)
                            .font(DS.Typo.titleLarge)
                            .foregroundStyle(outcomeColor)
                    }
                }
            }
        }
        .onAppear {
            if reduceMotion {
                revealProgress = 1
            } else {
                withAnimation(DS.Motion.scoreSpring.delay(0.2)) {
                    revealProgress = 1
                }
            }
            // Now that the visible reveal is happening, announce the
            // breakdown to VoiceOver users. This used to fire in
            // resolveWith() and leaked the bet before the user decided.
            announceReveal()
        }
    }

    private var outcomeBanner: some View {
        HStack(spacing: DS.Space.sm) {
            Image(systemName: bannerIcon)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: revealProgress)
                .font(.system(size: 18, weight: .medium))
            Text(bannerText)
                .font(.system(.body, design: .default, weight: .semibold))
                .kerning(0.5)
                .textCase(.uppercase)
        }
        .foregroundStyle(outcomeColor)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [outcomeColor.opacity(0.18), outcomeColor.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(outcomeColor.opacity(0.25), lineWidth: 0.5)
        )
    }

    private var bannerIcon: String {
        switch selectedOutcome {
        case .yes: "checkmark.circle.fill"
        case .no: "xmark.circle.fill"
        case .ambiguous: "questionmark.circle.fill"
        default: "circle"
        }
    }

    private var scoreImpactCard: some View {
        VStack(spacing: DS.Space.sm) {
            Text("This prediction scored")
                .font(DS.Typo.callout)
                .foregroundStyle(DS.Palette.textSecondary)

            let individual = individualBrier
            Text(PariFormat.brier(individual))
                .font(DS.Typo.titleLarge)
                .foregroundStyle(DS.Palette.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Space.base)
    }

    @ViewBuilder
    private var calibrationContext: some View {
        let bucket = ConfidenceLevel.snap(prediction.confidencePercent)
        let range = bucket >= 90 ? "90%+" : "\(bucket)-\(bucket + 9)%"

        Text("At \(range) confidence, watch your calibration curve to see how you actually perform.")
            .font(DS.Typo.callout)
            .foregroundStyle(DS.Palette.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.Space.base)
    }

    // MARK: - Actions

    private func resolveWith(_ outcome: ResolutionOutcome, fudged: Bool) {
        HapticEngine.shared.resolutionReveal()
        selectedOutcome = outcome
        wasFudged = fudged
        engine.resolve(prediction, outcome: outcome, fudged: fudged, in: context)

        // Phase 1 announcement must NOT include the confidence percent —
        // that's the honesty mechanic. The reveal-phase onAppear announces
        // the full breakdown only after the user's answer is locked in.
        let phase1: String
        switch outcome {
        case .yes: phase1 = "Marked yes. Revealing your prediction."
        case .no: phase1 = "Marked no. Revealing your prediction."
        case .ambiguous: phase1 = "Marked ambiguous."
        case .unresolved: phase1 = ""
        }
        if !phase1.isEmpty { A11y.announce(phase1) }

        if reduceMotion {
            step = .reveal
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                step = .reveal
            }
        }
    }

    /// Fires from the reveal phase only — confidence is now safe to surface
    /// because the user's answer is locked in.
    private func announceReveal() {
        guard let outcome = selectedOutcome, outcome != .ambiguous else { return }
        let formatted = PariFormat.brier(individualBrier)
        A11y.announce("You predicted \(prediction.confidencePercent) percent. The outcome was \(outcome == .yes ? "yes" : "no"). Brier score \(formatted).")
    }

    // MARK: - Computed

    private var individualBrier: Double {
        guard let outcome = selectedOutcome else { return 0 }
        if outcome == .ambiguous { return 0 }
        return ScoringEngine.brierScore(
            confidencePercent: prediction.confidencePercent,
            outcome: outcome == .yes
        )
    }

    private var outcomeLabel: String {
        switch selectedOutcome {
        case .yes: "Yes"
        case .no: "No"
        case .ambiguous: "Ambiguous"
        default: "—"
        }
    }

    private var outcomeColor: Color {
        switch selectedOutcome {
        case .yes: DS.Palette.semanticYes
        case .no: DS.Palette.semanticNo
        case .ambiguous: DS.Palette.semanticAmbiguous
        default: DS.Palette.textTertiary
        }
    }

    private var bannerText: String {
        switch selectedOutcome {
        case .yes: "Correct"
        case .no: "Incorrect"
        case .ambiguous: "Ambiguous"
        default: ""
        }
    }
}
