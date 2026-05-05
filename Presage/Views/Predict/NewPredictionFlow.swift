import SwiftUI
import SwiftData

struct NewPredictionFlow: View {
    @Environment(PariEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var claim = ""
    @State private var confidencePercent = 70
    @State private var resolutionCriteria = ""
    @State private var resolutionDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now.addingTimeInterval(7 * 24 * 60 * 60)
    @State private var category: PredictionCategory = .behavior
    @State private var moodTag: MoodTag?
    @State private var witnessName = ""
    @State private var showOptionalExtras = false
    @State private var selectedDatePreset: DatePreset? = .oneWeek

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case claim, criteria, witness
    }

    private enum DatePreset: String, CaseIterable {
        case tomorrow = "Tomorrow"
        case oneWeek = "1 week"
        case oneMonth = "1 month"
        case threeMonths = "3 months"
        case custom = "Custom"
    }

    private var canSave: Bool {
        claim.count >= 5 &&
        resolutionCriteria.count >= 5 &&
        resolutionDate > .now
    }

    /// Live quality assessment so the user can sharpen vague predictions
    /// before saving. Ran inline starting at the criteria step.
    private var liveQualityFlag: QualityFlag {
        QualityChecker.assess(claim: claim, criteria: resolutionCriteria)
    }

    private var showHelpers: Bool {
        engine.predictionCount < 5
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    claimStep
                    if claim.count >= 5 { confidenceStep }
                    if claim.count >= 5 { criteriaStep }
                    if resolutionCriteria.count >= 5 { dateStep }
                    if resolutionDate > .now && resolutionCriteria.count >= 5 { optionalsStep }
                }
                .padding(DS.Space.base)
                .padding(.bottom, 120)
                .animation(DS.Motion.stateAnimation, value: claim.count >= 5)
                .animation(DS.Motion.stateAnimation, value: resolutionCriteria.count >= 5)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DS.Palette.surfacePrimary)
            .safeAreaInset(edge: .bottom) {
                saveBar
            }
            .navigationTitle("New Prediction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Palette.textSecondary)
                }
            }
            .onAppear {
                focusedField = .claim
            }
        }
    }

    // MARK: - Step 1: Claim

    private var claimStep: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text("What do you predict?")
                .font(DS.Typo.titleLarge)
                .foregroundStyle(DS.Palette.textPrimary)

            ClaimInput(text: $claim)

            if showHelpers {
                Text("Write it as a statement that will be true or false. Lean toward 'no'? Tap Flip.")
                    .font(DS.Typo.footnote)
                    .foregroundStyle(DS.Palette.textTertiary)
            }
        }
    }

    // MARK: - Step 2: Confidence

    private var confidenceStep: some View {
        VStack(alignment: .leading, spacing: DS.Space.base) {
            Text("How confident are you?")
                .font(DS.Typo.titleLarge)
                .foregroundStyle(DS.Palette.textPrimary)

            ConfidenceDial(confidencePercent: $confidencePercent)
                .frame(maxWidth: .infinity)

            if showHelpers {
                Text("50% means coin flip. 90% means you'd bet real money.")
                    .font(DS.Typo.footnote)
                    .foregroundStyle(DS.Palette.textTertiary)
                    .italic()
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Step 3: Resolution Criteria

    private var criteriaStep: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text("What counts as yes?")
                .font(DS.Typo.titleLarge)
                .foregroundStyle(DS.Palette.textPrimary)

            PariInput(
                placeholder: "I've read the last page and can describe the ending",
                text: $resolutionCriteria,
                isMultiline: true
            )
            .focused($focusedField, equals: .criteria)

            if resolutionCriteria.count >= 5 && liveQualityFlag == .vague {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Palette.accentSecondary)
                    Text("This still reads as vague. Add an observable event, threshold, or date — future you needs something unambiguous to resolve against.")
                        .font(DS.Typo.footnote)
                        .foregroundStyle(DS.Palette.accentSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
                .transition(.opacity)
            } else if showHelpers {
                Text("Be specific — future you will thank present you")
                    .font(DS.Typo.footnote)
                    .foregroundStyle(DS.Palette.textTertiary)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(DS.Motion.stateAnimation, value: liveQualityFlag)
    }

    // MARK: - Step 4: Resolution Date

    private var dateStep: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text("When will you know?")
                .font(DS.Typo.titleLarge)
                .foregroundStyle(DS.Palette.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Space.sm) {
                    ForEach(DatePreset.allCases, id: \.self) { preset in
                        PariChip(
                            label: preset.rawValue,
                            isSelected: selectedDatePreset == preset
                        ) {
                            selectedDatePreset = preset
                            if let date = dateForPreset(preset) {
                                resolutionDate = date
                            }
                        }
                    }
                }
            }

            if selectedDatePreset == .custom {
                DatePicker(
                    "Resolution date",
                    selection: $resolutionDate,
                    in: (Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now.addingTimeInterval(86_400))...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .tint(DS.Palette.accent)
            }

            Text("Resolves \(resolutionDate.formatted(.dateTime.month(.wide).day().year()))")
                .font(DS.Typo.callout)
                .foregroundStyle(DS.Palette.textSecondary)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Step 5: Optionals

    private var optionalsStep: some View {
        VStack(alignment: .leading, spacing: DS.Space.base) {
            Button {
                withAnimation(DS.Motion.stateAnimation) {
                    showOptionalExtras.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: showOptionalExtras ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                    Text("Add details")
                        .font(DS.Typo.subhead)
                }
                .foregroundStyle(DS.Palette.textSecondary)
            }

            if showOptionalExtras {
                VStack(alignment: .leading, spacing: DS.Space.base) {
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        Text("Category")
                            .font(DS.Typo.footnote)
                            .foregroundStyle(DS.Palette.textTertiary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.Space.sm) {
                                ForEach(PredictionCategory.allCases) { cat in
                                    PariChip(
                                        label: cat.displayName,
                                        isSelected: category == cat
                                    ) {
                                        category = cat
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        Text("How are you feeling right now?")
                            .font(DS.Typo.footnote)
                            .foregroundStyle(DS.Palette.textTertiary)

                        HStack(spacing: DS.Space.md) {
                            ForEach(MoodTag.allCases) { mood in
                                MoodIndicator(mood: mood, isSelected: moodTag == mood) {
                                    moodTag = moodTag == mood ? nil : mood
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        Text("Tag a witness (optional)")
                            .font(DS.Typo.footnote)
                            .foregroundStyle(DS.Palette.textTertiary)

                        PariInput(placeholder: "Name", text: $witnessName)
                            .focused($focusedField, equals: .witness)
                    }
                }
                .transition(.opacity)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Save Bar

    private var saveBar: some View {
        VStack(spacing: 6) {
            PariButton("Save prediction") {
                savePrediction()
            }
            .opacity(canSave ? 1 : 0.4)
            .disabled(!canSave)

            if !canSave {
                Text(saveBlockedReason)
                    .font(DS.Typo.footnote)
                    .foregroundStyle(DS.Palette.textTertiary)
            }
        }
        .padding(.horizontal, DS.Space.base)
        .padding(.vertical, DS.Space.md)
        .reducibleMaterial(.ultraThinMaterial, fallback: DS.Palette.surfaceSecondary)
    }

    private var saveBlockedReason: String {
        if claim.count < 5 { return "Claim needs at least 5 characters" }
        if resolutionCriteria.count < 5 { return "Criteria needs at least 5 characters" }
        if resolutionDate <= .now { return "Resolution date must be in the future" }
        return ""
    }

    // MARK: - Helpers

    private func dateForPreset(_ preset: DatePreset) -> Date? {
        let cal = Calendar.current
        switch preset {
        case .tomorrow: return cal.date(byAdding: .day, value: 1, to: .now)
        case .oneWeek: return cal.date(byAdding: .day, value: 7, to: .now)
        case .oneMonth: return cal.date(byAdding: .month, value: 1, to: .now)
        case .threeMonths: return cal.date(byAdding: .month, value: 3, to: .now)
        case .custom: return nil
        }
    }

    private func savePrediction() {
        guard canSave else { return }
        // Run the same sanitizer the CSV importer and intents use:
        // strips control chars + Unicode bidi overrides + caps length.
        // Without this, a pasted claim from a hostile/trolling source
        // could carry RTL-override marks that flip rendering inside
        // notifications and share cards.
        let cleanedClaim = UserTextSanitizer.sanitize(claim, maxLength: 500)
        let cleanedCriteria = UserTextSanitizer.sanitize(resolutionCriteria, maxLength: 1000)
        // Re-validate post-sanitize: if a claim was 500 control chars it
        // would now be empty and shouldn't save.
        guard cleanedClaim.count >= 5, cleanedCriteria.count >= 5 else { return }

        engine.createPrediction(
            claim: cleanedClaim,
            resolutionCriteria: cleanedCriteria,
            confidencePercent: confidencePercent,
            resolutionDate: resolutionDate,
            category: category,
            moodTag: moodTag,
            witnessName: {
                let trimmed = witnessName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return UserTextSanitizer.sanitize(trimmed, maxLength: 100).isEmpty
                    ? nil
                    : UserTextSanitizer.sanitize(trimmed, maxLength: 100)
            }(),
            in: context
        )
        HapticService.success()
        dismiss()
    }
}

// MARK: - Mood Indicator

struct MoodIndicator: View {
    let mood: MoodTag
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(DS.Palette.textSecondary.opacity(fillOpacity))
                .frame(width: 32, height: 32)
                .overlay {
                    Circle()
                        .strokeBorder(
                            isSelected ? DS.Palette.accent : DS.Palette.separator,
                            lineWidth: isSelected ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.displayName)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var fillOpacity: Double {
        Double(mood.level) / 5.0
    }
}
