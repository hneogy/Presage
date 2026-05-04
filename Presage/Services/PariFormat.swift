import Foundation

/// Locale-aware number formatting helpers. Replaces `PariFormat.brier(...)`
/// callsites which produce `0.111` regardless of locale — incorrect in
/// any region whose decimal separator is `,` (most of Europe).
enum PariFormat {

    /// 3-fraction-digit Brier formatting using the device's locale.
    static func brier(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(3)))
    }

    /// 2-fraction-digit formatting (used for chart axis labels).
    static func twoFraction(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    /// Whole-number percent.
    static func percent(_ value: Int) -> String {
        // The Swift number-formatter percent style adds the locale's
        // percent symbol with appropriate spacing.
        Double(value).formatted(.percent.precision(.fractionLength(0)))
    }

    /// Whole-number percent from a 0...1 fraction.
    static func percentFromFraction(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }
}
