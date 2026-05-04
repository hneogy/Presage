import SwiftUI

/// Tier-2 yearly recap. Renders an animated SwiftUI view that progresses
/// from January→December, animating the user's calibration curve drawing
/// itself. Used as Instagram-bait shareable. The "video export" itself
/// uses the platform's screen-record path; the view here is the source.
struct YearlyRecapView: View {
    let buckets: [CalibrationBucket]
    let totalResolved: Int
    let brierScore: Double?
    @State private var progress: CGFloat = 0
    @State private var monthIndex: Int = 0

    private let months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0E1A24), Color(hex: 0x070D12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color(hex: 0x2FA8A8).opacity(0.25), .clear],
                center: UnitPoint(x: 0.5, y: 0.5),
                startRadius: 0, endRadius: 500
            )

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("MY \(Calendar.current.component(.year, from: .now))")
                        .font(.system(size: 14, weight: .semibold))
                        .kerning(3.0)
                        .foregroundStyle(Color(hex: 0x8B9AA6))
                    Text("CALIBRATION YEAR")
                        .font(.system(size: 22, weight: .bold))
                        .kerning(2.0)
                        .foregroundStyle(Color(hex: 0xF2EDE6))
                }

                // Animating month
                Text(months[monthIndex % 12])
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: 0xF4A88A))
                    .kerning(-2.0)
                    .contentTransition(.numericText())

                // Animating curve
                MiniCurve(buckets: buckets, progress: progress)
                    .frame(height: 140)
                    .padding(.horizontal, 40)

                // Final stats — fade in at end
                if progress >= 0.99 {
                    VStack(spacing: 6) {
                        if let b = brierScore {
                            Text("BRIER \(PariFormat.brier(b))")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .kerning(1.5)
                                .foregroundStyle(Color(hex: 0x2FA8A8))
                                .monospacedDigit()
                        }
                        Text("\(totalResolved) PREDICTIONS RESOLVED")
                            .font(.system(size: 12, weight: .semibold))
                            .kerning(2.0)
                            .foregroundStyle(Color(hex: 0x8B9AA6))
                    }
                    .transition(.opacity)
                }
            }
            .padding(.vertical, 64)
        }
        .frame(width: 1080, height: 1920)
        .onAppear {
            animate()
        }
    }

    private func animate() {
        // Structured concurrency — single Task that gets cancelled when
        // the view disappears, rather than 12 floating DispatchQueue
        // closures that fire even after the view is gone.
        Task { @MainActor in
            for i in 0..<12 {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    monthIndex = i
                    progress = CGFloat(i + 1) / 12.0
                }
            }
        }
    }
}

private struct MiniCurve: Shape {
    let buckets: [CalibrationBucket]
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sorted = buckets.filter { $0.predictionCount > 0 }.sorted { $0.confidencePercent < $1.confidencePercent }
        guard !sorted.isEmpty else { return path }

        let visibleCount = max(1, Int(CGFloat(sorted.count) * progress))
        let visible = Array(sorted.prefix(visibleCount))

        for (i, bucket) in visible.enumerated() {
            let x = rect.minX + (CGFloat(bucket.confidencePercent - 50) / 49.0) * rect.width
            let y = rect.maxY - (CGFloat(bucket.hitRatePercent) / 100.0) * rect.height
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

extension YearlyRecapView {
    func strokedView() -> some View {
        ZStack {
            self
        }
    }
}
