import SwiftUI
import SwiftData

struct AnnualReportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @State private var pdfData: Data? = nil
    @State private var generating = false
    @State private var errorMessage: String? = nil

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
                if generating {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Building PDF…")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    PariButton("Generate PDF") {
                        generatePDF()
                    }
                    if pdfData != nil {
                        PariButton("Share PDF", style: .secondary, icon: "square.and.arrow.up") {
                            presentShare()
                        }
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Palette.accentSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func generatePDF() {
        generating = true
        errorMessage = nil
        // ImageRenderer + UIGraphicsPDFRenderer are MainActor-bound, so we
        // can't truly background the work — but yielding once gives SwiftUI
        // a frame to paint the spinner before the synchronous PDF pass
        // begins, which is the difference between a janky tap and a
        // visibly-progressing operation.
        Task { @MainActor in
            await Task.yield()
            let result = AnnualReportRenderer.renderPDF(data: data)
            pdfData = result
            generating = false
            if result == nil {
                errorMessage = "Couldn't render the PDF. Try again, or restart Présage."
            }
        }
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
        // Per-invocation UUID suffix so a hostile process on the device
        // can't predict the exact /tmp path and stage a swap between
        // our `write(to:)` and the share sheet picking the file up.
        // Atomic write also defends against partial-write corruption.
        let suffix = UUID().uuidString.prefix(8)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Presage-Calibration-Report-\(suffix).pdf")
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        } catch {
            errorMessage = "Couldn't save the PDF for sharing: \(error.localizedDescription)"
            return
        }

        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            errorMessage = "Couldn't open the share sheet right now. Try again."
            return
        }
        var presenting = root
        while let next = presenting.presentedViewController { presenting = next }
        presenting.present(activity, animated: true)
    }
}
