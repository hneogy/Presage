import SwiftUI

struct BiasEncyclopediaView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selected: BiasLibrary.Bias? = nil
    /// Remember the last bias the user viewed so that returning from the
    /// detail sheet (or relaunching the app) keeps that bias highlighted.
    @AppStorage("lastViewedBiasID") private var lastViewedBiasID: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ForEach(BiasLibrary.all) { bias in
                    Button {
                        selected = bias
                        lastViewedBiasID = bias.id
                    } label: {
                        biasCard(bias, highlighted: bias.id == lastViewedBiasID)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.insights(colorScheme))
        .navigationTitle("Cognitive Biases")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { bias in
            BiasDetailSheet(bias: bias)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: "Educational")
            Text("Cognitive Biases")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.5)
            Text("Présage names the bias when it spots one in your patterns. Tap any to read more.")
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.textSecondary)
                .lineSpacing(2)
                .padding(.top, 4)
        }
    }

    private func biasCard(_ bias: BiasLibrary.Bias, highlighted: Bool = false) -> some View {
        PariCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(bias.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DS.Palette.textPrimary)
                    if highlighted {
                        Text("Last viewed")
                            .font(.system(size: 9, weight: .semibold))
                            .kerning(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(DS.Palette.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(DS.Palette.accentMuted))
                    }
                }
                Text(bias.oneLiner)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Palette.textSecondary)
                    .italic()
            }
        }
    }
}

struct BiasDetailSheet: View {
    let bias: BiasLibrary.Bias
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(bias.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(DS.Palette.textPrimary)
                        .kerning(-0.4)

                    Text(bias.oneLiner)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DS.Palette.accentSecondary)
                        .italic()

                    Text(bias.plainEnglish)
                        .font(.system(size: 15))
                        .foregroundStyle(DS.Palette.textPrimary)
                        .lineSpacing(4)

                    Divider().background(DS.Palette.separator)

                    HStack {
                        WhisperLabel(text: "Source")
                        Text(bias.researchCitation)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Palette.textSecondary)
                    }
                }
                .padding(20)
            }
            .background(DS.Palette.surfacePrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DS.Palette.accent)
                }
            }
        }
    }
}
