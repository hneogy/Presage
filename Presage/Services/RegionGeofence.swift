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

    /// Sentinel value users see when they explicitly chose "skip / ask
    /// later" — distinguishes that from a never-prompted user so the
    /// state-selector prompt doesn't keep nagging them.
    static let skippedStateCode = "__SKIPPED__"

    /// Returns true if Kalshi/Polymarket-branded questions should be hidden.
    /// We default to "show" globally; only restrict when we're confident
    /// the device is in a restricted US state via region setting.
    static func shouldHidePredictionMarketBranding() -> Bool {
        let regionCode = Locale.current.region?.identifier ?? ""
        guard regionCode == "US" else { return false }

        // The iOS region is country-level, not state-level. We hide
        // branding only when the user has confirmed they're in one of
        // the restricted states. A user who hasn't picked yet (or who
        // explicitly tapped "ask me later") sees the unrestricted UI —
        // they can still get into trouble in a restricted state, but
        // forever-hiding for everyone unselected was punishing the 90%
        // who live in unrestricted states.
        let stored = UserDefaults.standard.string(forKey: "user-state-code") ?? ""
        if stored.isEmpty || stored == skippedStateCode {
            return false
        }
        return restrictedUSStates.contains(stored)
    }

    /// Whether the user has acknowledged where they are. The skip
    /// sentinel counts as "selected" for prompt-suppression purposes —
    /// the user said "leave me alone", which is its own valid answer.
    static func userHasSelectedState() -> Bool {
        let stored = UserDefaults.standard.string(forKey: "user-state-code") ?? ""
        return !stored.isEmpty
    }

    /// Allowed alphabet for state-code validation. Two-letter US state
    /// codes are the only legitimate input; anything longer would flow
    /// through to the predicate without being matched by `restrictedUSStates`,
    /// but it would also bloat UserDefaults if a malicious caller passed
    /// a megabyte string. Cap and whitelist defensively.
    private static let stateCodeMaxLength = 4

    static func setUserState(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        // Allow the skip sentinel verbatim; otherwise enforce the
        // 2-4 character alphabetic bound that real state codes fit.
        if trimmed == skippedStateCode {
            UserDefaults.standard.set(skippedStateCode, forKey: "user-state-code")
            return
        }
        guard trimmed.count >= 2,
              trimmed.count <= stateCodeMaxLength,
              trimmed.allSatisfy({ $0.isLetter }) else {
            return
        }
        UserDefaults.standard.set(trimmed, forKey: "user-state-code")
    }

    /// Records that the user dismissed the state selector without
    /// picking. Treated as "show me the unrestricted UI and stop asking".
    static func skipStateSelection() {
        UserDefaults.standard.set(skippedStateCode, forKey: "user-state-code")
    }

    static func currentUserState() -> String? {
        let stored = UserDefaults.standard.string(forKey: "user-state-code")
        if stored == skippedStateCode { return nil }
        return stored
    }

    /// Description users see if they're in a restricted region.
    static var restrictedNotice: String {
        "Public market mirroring is unavailable in your region. You can still create your own personal predictions about any of these topics."
    }
}
