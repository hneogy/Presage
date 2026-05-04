import SwiftUI
import SwiftData

struct AnnualReportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @State private var pdfData: Data? = nil

    @Query(filter: #Predicate<Prediction> { $0.outcomeRaw != nil })
    private var resolved: [Prediction]

    @Query(filter: #Predicate<CalibrationSnapshot> { _ in true },
           sort: \CalibrationSnapshot.computedAt, order: .reverse)
    private var snapshots: [CalibrationSnapshot]

    private var data: AnnualReportRenderer.YearData {
        AnnualReportRenderer.gather(predictions: resolved, snapshot: snapshots.first)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                summaryCard
                PariButton("Generate PDF") {
                    pdfData = AnnualReportRenderer.renderPDF(data: data)
                }
                if pdfData != nil {
                    PariButton("Share PDF", style: .secondary, icon: "square.and.arrow.up") {
                        presentShare()
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.insights(colorScheme))
        .navigationTitle("Annual Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: "Yearly")
            Text("Calibration Report")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.4)
            Text("A printable record of your year of predictions, scored and surfaced.")
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.textSecondary)
                .lineSpacing(2)
                .padding(.top, 4)
        }
    }

    private var summaryCard: some View {
        PariCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        WhisperLabel(text: "Year")
                        Text("\(String(data.year))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Palette.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        WhisperLabel(text: "Resolved")
                        Text("\(data.totalResolved)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Palette.accentSecondary)
                            .monospacedDigit()
                    }
                }
                Divider().background(DS.Palette.separator)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        WhisperLabel(text: "Brier")
                        Text(brierString)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Palette.accent)
                            .monospacedDigit()
                    }
                    Spacer()
                    if let b = data.brierScore {
                        Text(ScoringEngine.benchmarkTier(for: b))
                            .font(.system(size: 11, weight: .semibold))
                            .kerning(1.2)
                            .foregroundStyle(DS.Palette.accentSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(DS.Palette.accentSecondaryMuted))
                    }
                }
            }
        }
    }

    private var brierString: String {
        guard let b = data.brierScore else { return "—" }
        return PariFormat.brier(b)
    }

    private func presentShare() {
        guard let data = pdfData else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Présage-Calibration-Report.pdf")
        try? data.write(to: url)

        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        var presenting = root
        while let next = presenting.presentedViewController { presenting = next }
        presenting.present(activity, animated: true)
    }
}
