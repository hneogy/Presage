import SwiftUI

extension DS {
    enum Typo {
        // Hero numerics — rounded, monospaced digits, used for the score
        static let heroNumber = Font.system(size: 88, weight: .bold, design: .rounded)
        static let heroNumberSmall = Font.system(size: 56, weight: .bold, design: .rounded)
        static let heroNumberTiny = Font.system(size: 36, weight: .semibold, design: .rounded)

        // Display
        static let displayLarge = Font.system(size: 34, weight: .bold, design: .default)
        static let displayMedium = Font.system(size: 28, weight: .semibold, design: .default)

        // Titles
        static let titleLarge = Font.system(size: 22, weight: .semibold, design: .default)
        static let titleMedium = Font.system(size: 17, weight: .semibold, design: .default)

        // Body
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        static let bodyEmphasized = Font.system(size: 16, weight: .medium, design: .default)
        static let callout = Font.system(size: 15, weight: .regular, design: .default)
        static let subhead = Font.system(size: 14, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)

        // Labels (uppercase, tracked) — the whisper labels above big numbers
        static let label = Font.system(size: 11, weight: .medium, design: .default)
        static let labelSmall = Font.system(size: 10, weight: .medium, design: .default)

        // Captions
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let captionEmphasized = Font.system(size: 12, weight: .semibold, design: .default)
    }

    enum Tracking {
        static let label: CGFloat = 1.6     // uppercase whisper labels
        static let display: CGFloat = -0.4  // tighter for large display text
        static let body: CGFloat = 0
    }
}

// Convenience: a "whisper label" — the tiny uppercase text that sits above big numbers
struct WhisperLabel: View {
    let text: String
    var color: Color = DS.Palette.textTertiary

    var body: some View {
        Text(text.uppercased())
            .font(DS.Typo.label)
            .foregroundStyle(color)
            .kerning(DS.Tracking.label)
    }
}
