import SwiftUI

enum DS {
    enum Palette {
        static let surfacePrimary = Color("surfacePrimary")
        static let surfaceSecondary = Color("surfaceSecondary")
        static let surfaceTertiary = Color("surfaceTertiary")

        static let textPrimary = Color("textPrimary")
        static let textSecondary = Color("textSecondary")
        static let textTertiary = Color("textTertiary")

        // The two halves of the icon: model (teal) vs reality (coral)
        static let accent = Color("accentPrimary")           // teal
        static let accentMuted = Color("accentPrimary").opacity(0.18)
        static let accentSecondary = Color("accentSecondary") // coral
        static let accentSecondaryMuted = Color("accentSecondary").opacity(0.18)

        static let chartPerfect = Color("chartPerfect")
        static let chartUser = Color("accentPrimary")
        static let chartOverconfident = Color("accentSecondary").opacity(0.22)
        static let chartUnderconfident = Color("accentPrimary").opacity(0.22)

        static let semanticYes = Color("accentPrimary")
        static let semanticNo = Color("accentSecondary")
        static let semanticAmbiguous = Color("textSecondary")

        static let separator = Color("pariSeparator")
    }
}

extension DS.Palette {
    // Locked tokens for places that need exact hex (icons, gradients, widgets)
    static let darkSurfacePrimary = Color(hex: 0x0A1218)      // deep navy/black
    static let darkSurfaceSecondary = Color(hex: 0x101920)    // raised surface
    static let darkSurfaceTertiary = Color(hex: 0x18242E)     // chip / input
    static let darkTextPrimary = Color(hex: 0xF2EDE6)         // warm off-white
    static let darkTextSecondary = Color(hex: 0x8B9AA6)       // cool slate
    static let darkTextTertiary = Color(hex: 0x4A5A66)        // dim label
    static let darkAccent = Color(hex: 0x2FA8A8)              // teal
    static let darkAccentSecondary = Color(hex: 0xF4A88A)     // coral
    static let darkSeparator = Color(hex: 0x1A252E)
    static let darkChartPerfect = Color(hex: 0x3A4A56)

    static let lightSurfacePrimary = Color(hex: 0xF6F4F0)
    static let lightSurfaceSecondary = Color.white
    static let lightSurfaceTertiary = Color(hex: 0xEDE9E2)
    static let lightTextPrimary = Color(hex: 0x0E1A24)
    static let lightTextSecondary = Color(hex: 0x6E7980)
    static let lightTextTertiary = Color(hex: 0xA8AFB5)
    static let lightAccent = Color(hex: 0x1F7878)
    static let lightAccentSecondary = Color(hex: 0xD27D5A)
    static let lightSeparator = Color(hex: 0xDCD7CE)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
