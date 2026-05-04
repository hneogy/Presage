import SwiftUI
import SwiftData

/// Edit an unresolved prediction. Resolved predictions are intentionally
/// never routed here — editing them would corrupt calibration history.
/// The list view's context menu only exposes "Edit" for unresolved
/// predictions, so this sheet's body assumes that invariant holds.
struct EditPredictionSheet: View {
    let prediction: Prediction
    @Environment(PariEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var claim: String = ""
    @State private var criteria: String = ""
    @State private var confidence: Int = 70
    @State private var resolutionDate: Date = .now
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section(label: "Claim") {
                        PariInput(placeholder: "I will...", text: $claim, isMultiline: true)
                    }

                    section(label: "What counts as yes") {
                        PariInput(placeholder: "Specific criteria", text: $criteria, isMultiline: true)
                    }

                    section(label: "Confidence") {
                        ConfidenceDial(confidencePercent: $confidence)
                            .padding(.vertical, 8)
                    }

                    section(label: "Resolves on") {
                        DatePicker(
                            "Resolution date",
                            selection: $resolutionDate,
                            in: Date.now...,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.compact)
                        .tint(DS.Palette.accent)
                        .labelsHidden()
                    }

                    PariButton("Save changes") { save() }
                        .opacity(canSave ? 1 : 0.4)
                        .disabled(!canSave)
                        .accessibilityHint(hasChanges
                                           ? "Saves your edits and reschedules notifications if the date changed."
                                           : "Disabled — no changes yet.")

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                            Text("Delete prediction")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(DS.Palette.accentSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            Capsule().fill(DS.Palette.accentSecondaryMuted.opacity(0.5))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete prediction")
                    .accessibilityHint("Removes the prediction and cancels its reminders. Cannot be undone.")
                }
                .padding(20)
            }
            .background(DS.Palette.surfacePrimary)
            .navigationTitle("Edit prediction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Palette.textSecondary)
                }
            }
            .alert("Delete this prediction?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    engine.deletePrediction(prediction, in: context)
                    dismiss()
                }
            } message: {
                Text("This removes it from the prediction list, calibration curve, and notification queue. This can't be undone.")
            }
        }
        .onAppear {
            claim = prediction.claim
            criteria = prediction.resolutionCriteria
            confidence = prediction.confidencePercent
            resolutionDate = prediction.resolutionDate
        }
    }

    @ViewBuilder
    private func section<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            WhisperLabel(text: label)
            content()
        }
    }

    /// Save is enabled only when (a) inputs are valid AND (b) something
    /// actually changed. Tapping save on a no-op shouldn't fire haptics.
    private var canSave: Bool {
        guard claim.count >= 5, criteria.count >= 5, resolutionDate > .now else { return false }
        return hasChanges
    }

    private var hasChanges: Bool {
        let claimChanged = claim.trimmingCharacters(in: .whitespacesAndNewlines)
            != prediction.claim.trimmingCharacters(in: .whitespacesAndNewlines)
        let criteriaChanged = criteria.trimmingCharacters(in: .whitespacesAndNewlines)
            != prediction.resolutionCriteria.trimmingCharacters(in: .whitespacesAndNewlines)
        let confidenceChanged = confidence != prediction.confidencePercent
        let dateChanged = abs(resolutionDate.timeIntervalSince(prediction.resolutionDate)) > 1
        return claimChanged || criteriaChanged || confidenceChanged || dateChanged
    }

    private func save() {
        let succeeded = engine.editPrediction(
            prediction,
            claim: claim.trimmingCharacters(in: .whitespacesAndNewlines),
            resolutionCriteria: criteria.trimmingCharacters(in: .whitespacesAndNewlines),
            confidencePercent: confidence,
            resolutionDate: resolutionDate,
            in: context
        )
        if succeeded {
            HapticEngine.shared.resolutionReveal()
            dismiss()
        }
    }
}
