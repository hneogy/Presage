import SwiftUI
import MessageUI

/// Sends a witness confirmation request via the system share sheet.
/// We don't need MFMessageComposeViewController-level integration —
/// a UIActivityViewController with prefilled text works on every device.
@MainActor
enum WitnessShareService {

    static func confirmationMessage(for prediction: Prediction) -> String {
        let claim = prediction.claim
        let resolutionLine = prediction.resolutionDate.formatted(.dateTime.month(.abbreviated).day().year())
        let preamble = "Présage is asking you to confirm a prediction I made."

        return """
        \(preamble)

        Prediction: "\(claim)"
        Resolves: \(resolutionLine)

        What counts as yes:
        \(prediction.resolutionCriteria)

        Did this happen?  Yes / No / Don't know

        (You only see this because I named you as a witness — Présage is a personal calibration app: pari.app)
        """
    }

    static func presentShareSheet(for prediction: Prediction) {
        let message = confirmationMessage(for: prediction)
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }

        var presenting = root
        while let next = presenting.presentedViewController {
            presenting = next
        }
        presenting.present(activityVC, animated: true)
    }
}
