import SwiftUI
import SwiftData

/// Tier-2 twin predictions. Make a prediction with a friend; both see each
/// other's confidence ONLY after both have resolved it. Privacy preserved:
/// the share is via iMessage (or any share sheet), no central server.
struct TwinPredictionsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @State private var claim = ""
    @State private var criteria = ""
    @State private var myConfidence: Int = 70
    @State private var resolutionDays: Int = 7

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ClaimInput(text: $claim, placeholder: "We both predict whether...")

                section("WHAT COUNTS AS YES") {
                    PariInput(placeholder: "Specific resolvable criteria", text: $criteria, isMultiline: true)
                }

                section("YOUR CONFIDENCE") {
                    ConfidenceDial(confidencePercent: $myConfidence)
                        .padding(.vertical, 8)
                }

                section("RESOLVES IN") {
                    HStack(spacing: 8) {
                        ForEach([7, 14, 30, 90], id: \.self) { days in
                            PariChip(label: "\(days)d", isSelected: resolutionDays == days) {
                                resolutionDays = days
                            }
                        }
                    }
                }

                explainerCard

                PariButton("Save · share with friend", icon: "person.2") {
                    save()
                }
                .opacity(canSave ? 1 : 0.4)
                .disabled(!canSave)
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.predict(colorScheme))
        .navigationTitle("Twin prediction")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: "With a friend")
            Text("Twin prediction")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.4)
            Text("You both lock in confidences privately. After resolution, both reveal. Lighter than a bet, heavier than a guess.")
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.textSecondary)
                .lineSpacing(2)
                .padding(.top, 4)
        }
    }

    private var explainerCard: some View {
        PariCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Your confidence is hidden until both resolve.", systemImage: "eye.slash")
                Label("No central server — sharing is via iMessage.", systemImage: "lock.shield")
                Label("Both Brier scores are revealed at the same time.", systemImage: "arrow.left.arrow.right")
            }
            .font(.system(size: 13))
            .foregroundStyle(DS.Palette.textSecondary)
        }
    }

    @ViewBuilder
    private func section<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.6)
                .foregroundStyle(DS.Palette.textTertiary)
            content()
        }
    }

    private var canSave: Bool {
        claim.count >= 5 && criteria.count >= 5
    }

    private func save() {
        let resolutionDate = Calendar.current.date(byAdding: .day, value: resolutionDays, to: .now) ?? .now
        let prediction = Prediction(
            claim: "Twin: \(claim)",
            resolutionCriteria: criteria,
            confidencePercent: myConfidence,
            resolutionDate: resolutionDate,
            category: .external,
            tags: ["twin"]
        )
        context.insert(prediction)
        try? context.save()

        // Share invite
        let invite = """
        Présage twin prediction:

        "\(claim)"

        What counts as yes:
        \(criteria)

        Resolves: \(resolutionDate.formatted(.dateTime.month(.abbreviated).day().year()))

        Lock in your own confidence (your number stays private until both resolve). Reply when you've decided.
        """
        let activity = UIActivityViewController(activityItems: [invite], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        var presenting = root
        while let next = presenting.presentedViewController { presenting = next }
        presenting.present(activity, animated: true)
    }
}
