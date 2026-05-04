import SwiftUI
import SwiftData

struct PublicMarketMirrorView: View {
    @Environment(PariEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSource: PublicMarketBrowser.PublicQuestion.Source? = nil
    @State private var showingStateSelector = false
    @State private var hideBranding: Bool = RegionGeofence.shouldHidePredictionMarketBranding()

    private var filtered: [PublicMarketBrowser.PublicQuestion] {
        let all = PublicMarketBrowser.curated
        guard let s = selectedSource else { return all }
        return all.filter { $0.source == s }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if hideBranding {
                    restrictedNotice
                }

                if !hideBranding {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            PariChip(label: "All", isSelected: selectedSource == nil) {
                                selectedSource = nil
                            }
                            ForEach([PublicMarketBrowser.PublicQuestion.Source.metaculus, .kalshi, .goodJudgment], id: \.rawValue) { s in
                                PariChip(label: s.rawValue, isSelected: selectedSource == s) {
                                    selectedSource = s
                                }
                            }
                        }
                    }
                }

                ForEach(filtered) { question in
                    publicQuestionCard(question)
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.predict(colorScheme))
        .navigationTitle(hideBranding ? "Forecasting Questions" : "Public markets")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingStateSelector) {
            StateSelectorSheet(onConfirm: {
                hideBranding = RegionGeofence.shouldHidePredictionMarketBranding()
            })
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: hideBranding ? "Forecasting" : "Inspiration")
            Text(hideBranding ? "Forecasting questions" : "Public markets")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.4)
            Text(hideBranding
                 ? "Browse forecasting questions and create your own personal predictions about them."
                 : "Mirror any public question as a personal prediction. Compare your calibration against the wisdom of crowds.")
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.textSecondary)
                .lineSpacing(2)
                .padding(.top, 4)

            if hideBranding {
                Button {
                    showingStateSelector = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                        Text(RegionGeofence.userHasSelectedState() ? "Change region" : "Set my region")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.Palette.accent)
                }
                .padding(.top, 4)
            }
        }
    }

    private var restrictedNotice: some View {
        PariCard(padding: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "globe.americas")
                    .foregroundStyle(DS.Palette.accentSecondary)
                    .font(.system(size: 14))
                Text(RegionGeofence.restrictedNotice)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Palette.textSecondary)
                    .lineSpacing(2)
            }
        }
    }

    private func publicQuestionCard(_ q: PublicMarketBrowser.PublicQuestion) -> some View {
        PariCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if !hideBranding {
                        Text(q.source.rawValue.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(1.5)
                            .foregroundStyle(DS.Palette.accent)
                    } else {
                        Text("FORECAST")
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(1.5)
                            .foregroundStyle(DS.Palette.accent)
                    }
                    Spacer()
                    Text(q.resolutionDate.formatted(.dateTime.month(.abbreviated).year()))
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Palette.textTertiary)
                }
                Text(q.claim)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .lineSpacing(2)

                Button {
                    mirror(question: q)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 13))
                        Text("Make personal prediction")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(DS.Palette.darkSurfacePrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Capsule().fill(DS.Palette.accentSecondary))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func mirror(question q: PublicMarketBrowser.PublicQuestion) {
        engine.createPrediction(
            claim: "Personal: \(q.claim)",
            resolutionCriteria: q.suggestedCriteria,
            confidencePercent: 60,
            resolutionDate: q.resolutionDate,
            category: q.category,
            moodTag: nil,
            witnessName: nil,
            in: context
        )
        HapticEngine.shared.resolutionReveal()
    }
}

// MARK: - State selector

struct StateSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onConfirm: () -> Void
    @State private var selectedState: String = RegionGeofence.currentUserState() ?? ""

    private static let usStates: [(code: String, name: String)] = [
        ("AL","Alabama"),("AK","Alaska"),("AZ","Arizona"),("AR","Arkansas"),
        ("CA","California"),("CO","Colorado"),("CT","Connecticut"),("DE","Delaware"),
        ("FL","Florida"),("GA","Georgia"),("HI","Hawaii"),("ID","Idaho"),
        ("IL","Illinois"),("IN","Indiana"),("IA","Iowa"),("KS","Kansas"),
        ("KY","Kentucky"),("LA","Louisiana"),("ME","Maine"),("MD","Maryland"),
        ("MA","Massachusetts"),("MI","Michigan"),("MN","Minnesota"),("MS","Mississippi"),
        ("MO","Missouri"),("MT","Montana"),("NE","Nebraska"),("NV","Nevada"),
        ("NH","New Hampshire"),("NJ","New Jersey"),("NM","New Mexico"),("NY","New York"),
        ("NC","North Carolina"),("ND","North Dakota"),("OH","Ohio"),("OK","Oklahoma"),
        ("OR","Oregon"),("PA","Pennsylvania"),("RI","Rhode Island"),("SC","South Carolina"),
        ("SD","South Dakota"),("TN","Tennessee"),("TX","Texas"),("UT","Utah"),
        ("VT","Vermont"),("VA","Virginia"),("WA","Washington"),("WV","West Virginia"),
        ("WI","Wisconsin"),("WY","Wyoming")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Your state determines whether prediction-market sources can be shown. Présage never collects this — it's stored locally.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Palette.textSecondary)
                        .listRowBackground(DS.Palette.surfaceSecondary)
                }
                Section {
                    ForEach(Self.usStates, id: \.code) { entry in
                        Button {
                            selectedState = entry.code
                            RegionGeofence.setUserState(entry.code)
                            onConfirm()
                            dismiss()
                        } label: {
                            HStack {
                                Text(entry.name)
                                    .foregroundStyle(DS.Palette.textPrimary)
                                Spacer()
                                if RegionGeofence.restrictedUSStates.contains(entry.code) {
                                    Text("Restricted")
                                        .font(.caption)
                                        .foregroundStyle(DS.Palette.accentSecondary)
                                }
                                if selectedState == entry.code {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(DS.Palette.accent)
                                }
                            }
                        }
                        .listRowBackground(DS.Palette.surfaceSecondary)
                    }
                } header: { Text("Region") }
            }
            .scrollContentBackground(.hidden)
            .background(DS.Palette.surfacePrimary)
            .navigationTitle("Region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(DS.Palette.accent)
                }
            }
        }
    }
}
