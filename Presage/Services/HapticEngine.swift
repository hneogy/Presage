import CoreHaptics
import Foundation

@MainActor
final class HapticEngine {
    static let shared = HapticEngine()

    private var engine: CHHapticEngine?

    private init() {
        prepare()
    }

    private func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine?.stoppedHandler = { _ in }
            try engine?.start()
        } catch {
            engine = nil
        }
    }

    /// Confidence dial tick — sharpness scales with confidence percent.
    /// At 50%: light, soft. At 95%+: heavy, sharp — the "weight of commitment".
    func confidenceTick(at percent: Int) {
        guard let engine else {
            HapticService.confidenceTick(at: percent)
            return
        }

        let normalized = Double(percent - 50) / 49.0
        let intensity = Float(0.4 + normalized * 0.6)
        let sharpness = Float(0.3 + normalized * 0.7)

        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            HapticService.confidenceTick(at: percent)
        }
    }

    /// Dramatic reveal pattern for the resolution flow — two beats.
    func resolutionReveal() {
        guard let engine else {
            HapticService.medium()
            return
        }

        let beat1 = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ],
            relativeTime: 0
        )

        let beat2 = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ],
            relativeTime: 0.2
        )

        do {
            let pattern = try CHHapticPattern(events: [beat1, beat2], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }
}
