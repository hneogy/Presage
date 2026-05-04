import Foundation
import CoreLocation

/// Region-based content gating for the Public Market Mirror feature.
///
/// As of April 2026, 13 US states have active enforcement against
/// prediction-market platforms (Kalshi, Polymarket). To stay clear of
/// App Store Review flags and avoid pointing users to content that's
/// illegal in their state, Pari hides explicitly-branded prediction
/// market questions in those regions.
///
/// We use `Locale.current.region` (no GPS, no permission prompt). That
/// returns the user's iOS region setting — coarse, but enough for App
/// Store compliance. CoreLocation imports are kept for future
/// finer-grained geofencing if needed.
enum RegionGeofence {

    /// US states with active prediction-market enforcement / litigation
    /// per April 2026 sources. List should be reviewed quarterly.
    static let restrictedUSStates: Set<String> = [
        "AZ", "IL", "MA", "MD", "MI", "MT", "NJ", "NV", "OH",
        "CT",   // Connecticut — active litigation
        "TN",   // Tennessee — ban blocked by federal injunction but disclosed
    ]

    /// Returns true if Kalshi/Polymarket-branded questions should be hidden.
    /// We default to "show" globally; only restrict when we're confident
    /// the device is in a restricted US state via region setting.
    static func shouldHidePredictionMarketBranding() -> Bool {
        let regionCode = Locale.current.region?.identifier ?? ""
        guard regionCode == "US" else { return false }

        // The iOS region is country-level, not state-level. Without GPS
        // permission we can't pinpoint state. The conservative play is
        // to hide branding for all US users until the user opts in via
        // a state selector in settings (privacy-respecting).
        let userSelectedState = UserDefaults.standard.string(forKey: "user-state-code") ?? ""
        if userSelectedState.isEmpty {
            // Unknown — show the neutralized "Forecasting questions" surface
            // rather than risk pointing users at content illegal where they live.
            return true
        }
        return restrictedUSStates.contains(userSelectedState)
    }

    /// Whether the user has acknowledged where they are. Lets us show the
    /// state-selector prompt once instead of forever-hiding.
    static func userHasSelectedState() -> Bool {
        (UserDefaults.standard.string(forKey: "user-state-code") ?? "").isEmpty == false
    }

    static func setUserState(_ code: String) {
        UserDefaults.standard.set(code, forKey: "user-state-code")
    }

    static func currentUserState() -> String? {
        UserDefaults.standard.string(forKey: "user-state-code")
    }

    /// Description users see if they're in a restricted region.
    static var restrictedNotice: String {
        "Public market mirroring is unavailable in your region. You can still create your own personal predictions about any of these topics."
    }
}
