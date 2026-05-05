import SwiftUI
import SwiftData

struct TemplatesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingEditor = false

    @Query(sort: \PredictionTemplate.startDate, order: .reverse)
    private var templates: [PredictionTemplate]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if templates.isEmpty {
                    PariEmptyState(
                        icon: "repeat",
                        title: "No recurring predictions",
                        message: "Create a template to auto-spawn predictions on a schedule.",
                        actionTitle: "New template"
                    ) {
                        showingEditor = true
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(templates) { template in
                        templateRow(template)
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.predict(colorScheme))
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(DS.Palette.accent)
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            TemplateEditor()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            WhisperLabel(text: "Recurring")
            Text("Templates")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.4)
        }
    }

    private func templateRow(_ template: PredictionTemplate) -> some View {
        PariCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(template.recurrence.displayName.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(DS.Palette.accent)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { template.isActive },
                        set: { newValue in
                            // Skip the SwiftData save when SwiftUI fires
                            // a redundant set() with the same value —
                            // happens on rapid taps and double-binding
                            // round trips. Removes thrashing on the store.
                            guard template.isActive != newValue else { return }
                            let prior = template.isActive
                            template.isActive = newValue
                            if !PariPersistence.attemptSave(context, label: "toggle template active") {
                                // Snap the toggle back so the UI doesn't
                                // claim active state we couldn't persist.
                                template.isActive = prior
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(DS.Palette.accent)
                }
                Text(template.claim)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Text("\(template.defaultConfidencePercent)%")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.Palette.accentSecondary)
                        .monospacedDigit()
                    Circle().fill(DS.Palette.textTertiary).frame(width: 2, height: 2)
                    Text("Resolves \(template.horizonDays)d after spawn")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Palette.textSecondary)
                }
            }
        }
    }
}

struct TemplateEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var claim: String = ""
    @State private var criteria: String = ""
    @State private var confidence: Int = 70
    @State private var category: PredictionCategory = .behavior
    @State private var recurrence: RecurrencePattern = .weekly
    @State private var horizonDays: Int = 7

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("Recurring claim") {
                        PariInput(placeholder: "I will work out 4× this week", text: $claim, isMultiline: true)
                    }

                    section("What counts as yes") {
                        PariInput(placeholder: "Specific resolution criteria", text: $criteria, isMultiline: true)
                    }

                    section("How often") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(RecurrencePattern.allCases, id: \.self) { p in
                                    PariChip(label: p.displayName, isSelected: recurrence == p) {
                                        recurrence = p
                                        horizonDays = p.intervalDays
                                    }
                                }
                            }
                        }
                    }

                    section("Confidence") {
                        ConfidenceDial(confidencePercent: $confidence)
                            .padding(.vertical, 8)
                    }

                    PariButton("Create template") {
                        let template = PredictionTemplate(
                            claim: claim,
                            resolutionCriteria: criteria,
                            defaultConfidencePercent: confidence,
                            category: category,
                            recurrence: recurrence,
                            horizonDays: horizonDays
                        )
                        context.insert(template)
                        guard PariPersistence.attemptSave(context, label: "create template") else {
                            // The recurrence spawner reads templates from
                            // the store — if the template never landed,
                            // running the spawner would do nothing useful
                            // and the user would think they had a working
                            // template. Roll back instead.
                            context.delete(template)
                            return
                        }
                        RecurrenceEngine.spawnDuePredictions(in: context)
                        dismiss()
                    }
                    .opacity(canSave ? 1 : 0.4)
                    .disabled(!canSave)
                }
                .padding(20)
            }
            .background(DS.Palette.surfacePrimary)
            .navigationTitle("New template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Palette.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func section<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            WhisperLabel(text: label)
            content()
        }
    }

    private var canSave: Bool {
        claim.count >= 5 && criteria.count >= 5
    }
}
