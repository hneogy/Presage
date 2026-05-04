import SwiftUI

/// Knowledge Center — a self-contained reference inside Présage covering
/// every topic a user might need: how to use the app, what each feature
/// does, the calibration math, privacy posture, accessibility support,
/// terms, and about.
///
/// Everything lives on-device. There are no remote help links — by
/// design. The privacy-first posture forbids fetching content over the
/// network just to render help.
struct KnowledgeCenterView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                topicRow(
                    title: "Getting started",
                    subtitle: "What Présage is, why calibrated forecasting matters",
                    icon: "sparkles",
                    tint: DS.Palette.accent
                ) {
                    GettingStartedArticle()
                }

                topicRow(
                    title: "The method",
                    subtitle: "Honesty mechanic · Brier score · calibration curve",
                    icon: "function",
                    tint: DS.Palette.accent
                ) {
                    MethodArticle()
                }

                topicRow(
                    title: "Features",
                    subtitle: "Every screen and tool in Présage, briefly",
                    icon: "square.grid.2x2.fill",
                    tint: DS.Palette.accentSecondary
                ) {
                    FeaturesArticle()
                }

                topicRow(
                    title: "How to use",
                    subtitle: "Gestures, shortcuts, FAB long-press, swipe actions",
                    icon: "hand.tap.fill",
                    tint: DS.Palette.accent
                ) {
                    HowToUseArticle()
                }

                topicRow(
                    title: "Privacy",
                    subtitle: "What's collected (nothing) and where it lives (this device)",
                    icon: "lock.shield.fill",
                    tint: DS.Palette.accent
                ) {
                    PrivacyArticle()
                }

                topicRow(
                    title: "Accessibility",
                    subtitle: "VoiceOver, Dynamic Type, reduced motion, contrast",
                    icon: "figure.roll",
                    tint: DS.Palette.accentSecondary
                ) {
                    AccessibilityArticle()
                }

                topicRow(
                    title: "Terms & Conditions",
                    subtitle: "Usage, warranty, dispute resolution",
                    icon: "doc.plaintext",
                    tint: DS.Palette.textSecondary
                ) {
                    TermsArticle()
                }

                topicRow(
                    title: "About",
                    subtitle: "Version, credits, contact, acknowledgments",
                    icon: "info.circle.fill",
                    tint: DS.Palette.textSecondary
                ) {
                    AboutArticle()
                }
            }
            .padding(20)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.more(colorScheme))
        .navigationTitle("Knowledge Center")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: "Help & About")
            Text("Knowledge Center")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.5)
            Text("Everything about Présage — how it works, what's private, how to navigate, and the math behind the score.")
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.textSecondary)
                .lineSpacing(2)
                .padding(.top, 4)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func topicRow<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Palette.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Palette.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Palette.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DS.Palette.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(DS.Palette.separator, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Article rendering primitives

/// Wraps a topic article with consistent padding, scroll, and back chrome.
private struct ArticleScroll<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DS.Palette.textPrimary)
                    .kerning(-0.5)
                    .padding(.top, 8)
                content
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.more(colorScheme))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Section heading inside an article.
private struct H2: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(DS.Palette.textPrimary)
            .padding(.top, 6)
    }
}

/// Body paragraph.
private struct P: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(DS.Palette.textSecondary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Single bullet item.
private struct Bullet: View {
    let label: String
    let body_: String
    init(_ label: String, _ body: String) {
        self.label = label
        self.body_ = body
    }
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(DS.Palette.accent)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Palette.textPrimary)
                Text(body_)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Palette.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Highlighted callout card.
private struct Callout: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.accent)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DS.Palette.accent.opacity(0.10))
        )
    }
}

// MARK: - Articles

private struct GettingStartedArticle: View {
    var body: some View {
        ArticleScroll("Getting started") {
            P("Présage is a personal calibrated forecasting tool. You predict things about your own life — behavior, work, relationships, external events — with a confidence percentage and a resolution date. Présage scores your accuracy over time using proper scoring rules and shows you the gap between how confident you are and how often you're actually right.")

            Callout("This is not a habit tracker, journal, or prediction market. It's a solo, honest mirror.")

            H2("Why calibration?")
            P("Most people think they're right 90% of the time when they're actually right 70%. The difference is overconfidence. Calibration training closes that gap. Forecasters who practice this consistently end up better at every kind of decision-making — investing, hiring, medical diagnosis, planning.")

            H2("How to start")
            Bullet("Make a prediction", "Tap the orange + button. Write what you predict, your confidence (50–99%), and what counts as 'yes.' Pick a resolution date.")
            Bullet("Wait for resolution day", "Présage notifies you when a prediction resolves. The notification deep-links you straight into the resolution flow.")
            Bullet("Resolve honestly", "You see only the claim and the criteria — your original confidence is hidden. You answer Yes / No / Ambiguous. Then Présage reveals what you said and updates your Brier score.")

            H2("The honesty mechanic")
            P("Présage hides your original confidence at resolution time. This is deliberate. If you saw '85%' before answering, you'd anchor on it and find ways to say 'yes, basically.' By hiding it, your answer is shaped only by what actually happened.")

            H2("What to predict about")
            P("Anything specific and verifiable. \"I'll go to the gym 3+ times this week\" — good. \"I'll have a productive week\" — bad (unverifiable). The more concrete the criteria, the more your calibration improves.")
        }
    }
}

private struct MethodArticle: View {
    var body: some View {
        ArticleScroll("The method") {
            H2("Brier score")
            P("Brier score is a proper scoring rule for probabilistic forecasts. For a single prediction:")
            P("Brier = (forecast − outcome)²")
            P("Where forecast is your confidence as a decimal (0.5–0.99) and outcome is 1 if it happened, 0 if it didn't. Lower is better. 0 is perfect; 0.25 is what you'd get from always saying 50% (random); 1.0 is impossible (would require saying 100% wrong).")

            Callout("A Brier score below 0.20 over 50+ resolved predictions is genuinely good calibration.")

            H2("Aggregate Brier")
            P("Across all your resolved predictions: the average of each individual Brier score. Présage excludes ambiguous outcomes and predictions you marked as 'fudged' — these aren't honest data points.")

            H2("Calibration curve")
            P("X-axis: your stated confidence buckets (50–60, 60–70, ..., 90–100). Y-axis: how often the predictions in that bucket actually came true. The diagonal line is perfect calibration. If your dots sit below the line, you're overconfident; above, underconfident.")

            H2("Log score")
            P("An alternative scoring rule: log₂(p) where p is your forecast for what actually happened. Penalizes confident wrong answers more harshly than Brier — useful for very high-stakes forecasts. Présage shows both.")

            H2("Why proper scoring rules?")
            P("'Proper' means the rule is minimized when you report your true belief. You can't game a Brier score by hedging — saying 70% when you really think 90% will hurt your score. This is what makes calibration real instead of theatre.")

            H2("Why the 50% floor?")
            P("Saying \"30% yes\" is the same forecast as \"70% no\" with the claim flipped. Présage standardizes by always asking 'how confident in YES.' If you think 'no,' flip the claim with the toggle in the editor — keeps every confidence ≥50%.")

            H2("Categories, horizons, mood")
            P("Présage breaks down your calibration by category (behavior / relationships / work / emotion / external), time horizon (under 1 week / 1–4 weeks / 1–3 months / 3+ months), and mood at the time of prediction. These breakdowns surface where you systematically overconfident or underconfident.")
        }
    }
}

private struct FeaturesArticle: View {
    var body: some View {
        ArticleScroll("Features") {
            H2("Core")
            Bullet("Home", "Dashboard — Brier hero, hit rate, active count, mini calibration curve, what's resolving soon.")
            Bullet("Predict", "Filterable list of all predictions, grouped by horizon. Swipe right to resolve, left to edit.")
            Bullet("Insights", "Year-in-pixels heatmap, full calibration curve, breakdowns by category / horizon / mood, wall of shame, confidence distribution.")
            Bullet("New Prediction", "Tap the orange + button. Progressive flow: claim → confidence → criteria → date → optional details.")
            Bullet("Quick Predict", "Long-press the + button. Streamlined flow with NLP-suggested confidence based on your phrasing.")
            Bullet("Resolution", "Two-phase. Phase 1 hides your original confidence and asks Yes / No / Ambiguous. Phase 2 reveals the impact on your score.")

            H2("Sharpen")
            Bullet("Présage Coach", "On-device LLM coach. Sunday retrospectives, claim sharpening, post-resolution reflection.")
            Bullet("Calibration Training", "Pre-resolved questions across topics. Instant feedback on calibration without the wait.")
            Bullet("Flashcards", "Anki-style study cards with calibration scoring on each answer.")
            Bullet("Cognitive biases", "Encyclopedia of named biases Présage watches for in your patterns (anchoring, motivated criteria, hindsight, others).")
            Bullet("Question packs", "Curated bundles of pre-written predictions by theme — career, health, relationships, world events.")

            H2("AI")
            Bullet("Score AI answers", "Pose the same question to GPT / Claude / your own confidence. Présage scores all three.")
            Bullet("AI keys", "Add your OpenAI / Anthropic API keys. Keys live on this device only — never proxied through a server.")

            H2("Long-horizon")
            Bullet("Life Forecast", "Write a 5-year vision in 5 domains (career / health / relationships / finances / personal). Each milestone becomes a resolvable prediction.")
            Bullet("Recurring templates", "Auto-spawn predictions on a schedule — weekly gym attendance, monthly savings goal, etc.")
            Bullet("Annual report", "Printable PDF of your year's calibration.")

            H2("Compare")
            Bullet("Where you stand", "Position on the canonical forecasting benchmark (ForecastBench, Metaculus, Manifold, Tetlock).")
            Bullet("Anonymous standing", "Where you sit globally. Opt-in only — no data leaves your device unless you toggle it on.")
            Bullet("Public market questions", "Mirror Metaculus / Manifold / Polymarket questions and lock in your own private forecast.")
            Bullet("Twin prediction", "Lock in a prediction with a friend. Your number stays private until both resolve.")
            Bullet("Présage for Teams", "Workspace-wide prediction tracking for organizations.")

            H2("Data")
            Bullet("Import from CSV", "Migrate from Fatebook, PredictionBook, or any spreadsheet with a 'claim' column.")
            Bullet("Markdown / Obsidian export", "Export your full vault as markdown with YAML frontmatter and wikilinks.")

            H2("Widgets & extensions")
            Bullet("Home Screen widgets", "Brier score widget, due-soon widget, smart stack adaptive widget.")
            Bullet("Lock Screen widgets", "Brier score in accessoryRectangular and accessoryCircular sizes.")
            Bullet("Live Activities", "Active prediction surfaces on your lock screen with hours-overdue counter.")
            Bullet("Watch app", "Quick view of your Brier score on Apple Watch.")
            Bullet("Siri shortcuts", "Quick-predict, resolve next due, view Brier, compare months — all via voice or Shortcuts app.")
        }
    }
}

private struct HowToUseArticle: View {
    var body: some View {
        ArticleScroll("How to use") {
            H2("Gestures")
            Bullet("Tap +", "Open the new prediction full flow.")
            Bullet("Long-press +", "Open Quick Predict — a streamlined sheet with NLP-suggested confidence.")
            Bullet("Swipe right on a prediction row", "Resolve it.")
            Bullet("Swipe left on a prediction row", "Edit it (only available before resolution — resolved predictions are immutable to protect calibration history).")
            Bullet("Tap a prediction row", "Open the detail sheet.")
            Bullet("Pull to refresh", "On Home, force a recompute of your calibration snapshot.")

            H2("The confidence dial")
            P("Drag the bar to set your confidence. Snaps to 5% increments. Haptic feedback at each tick, heavier at 50/80/95. The bar floor is 50% — to predict 'no,' tap the Flip button to invert your claim.")

            H2("Notifications")
            P("On resolution day, Présage sends a notification with the claim. Tap it to deep-link straight into the resolution flow. If you don't resolve within a day, you get a gentle reminder; at 7 days overdue, the tone sharpens.")

            H2("Siri shortcuts")
            P("All shortcuts work via voice. Try:")
            Bullet("\"Hey Siri, quick predict in Présage\"", "Opens the streamlined prediction sheet.")
            Bullet("\"Hey Siri, resolve in Présage\"", "Opens the next overdue prediction.")
            Bullet("\"Hey Siri, what's my Présage Brier score?\"", "Speaks your current Brier without opening the app.")
            Bullet("\"Hey Siri, did I improve in Présage this month?\"", "Compares this month vs last.")

            H2("Deep links")
            P("Présage handles a custom URL scheme for in-app navigation:")
            Bullet("pari://create", "Opens the new prediction flow.")
            Bullet("pari://quick", "Opens Quick Predict.")
            Bullet("pari://resolve/<UUID>", "Opens the resolution flow for a specific prediction.")
            Bullet("pari://insights", "Jumps to the Insights tab.")
            Bullet("pari://coach", "Opens the Coach view.")

            H2("Settings shortcuts")
            P("Tap the gear icon on Home (top-right) or navigate via More → Account → Settings. Both reach the same place.")

            H2("Force-quit reset for sync")
            P("Toggling iCloud sync requires a force-quit and relaunch — the model container is built once at app launch, so the sync setting only takes effect on next launch.")
        }
    }
}

private struct PrivacyArticle: View {
    var body: some View {
        ArticleScroll("Privacy") {
            Callout("Présage collects nothing. All data lives on your device.")

            H2("What's stored locally")
            P("Every prediction, calibration snapshot, mood tag, and AI scoring result is written to a SwiftData store inside the app's container on this device. No telemetry, no analytics, no crash reports leave the device unless you explicitly opt in to features below.")

            H2("Optional iCloud sync")
            P("Off by default. If you turn it on (Settings → iCloud Sync), your SwiftData store syncs through your private CloudKit database — visible to you across your Apple ID's devices, never to Présage. Apple operates the CloudKit infrastructure under their privacy policy.")

            H2("HealthKit (optional)")
            P("Présage can read your State of Mind entries to pre-fill mood when creating predictions. This is opt-in and runs entirely on-device. Présage never writes to HealthKit and never transmits the data anywhere.")

            H2("AI features")
            P("Apple Foundation Models (the on-device LLM available on iOS 18+ on supported devices) runs entirely locally. No prompts leave your device.")
            P("If you add your own OpenAI / Anthropic API keys (Settings → AI keys), prompts go directly from your device to those providers. Présage never proxies, logs, or sees any of this. The keys live in this device's keychain.")

            H2("Anonymous standing (opt-in)")
            P("If you opt in to the global leaderboard, Présage submits a single number — your aggregated Brier score — under a pseudonym you control. No prediction text, no dates, no metadata. You can opt out anytime; the next sync removes your entry.")

            H2("Required-reason API declarations")
            P("iOS requires apps to declare why they use certain APIs. Présage uses:")
            Bullet("UserDefaults", "To remember your preferences (theme, notification cadence, etc.).")
            Bullet("File timestamp APIs", "To order your prediction history correctly.")
            Bullet("System boot time", "To compute relative timestamps for Live Activities.")
            Bullet("Disk space APIs", "To warn you before exporting a vault that wouldn't fit.")
            P("None of these are tied to identification or tracking.")

            H2("No third-party SDKs")
            P("Présage ships with zero analytics, advertising, or attribution SDKs. The code that runs on your device is just SwiftUI, SwiftData, ActivityKit, WidgetKit, App Intents, and HealthKit — all Apple frameworks.")

            H2("App Tracking Transparency")
            P("Présage does not track. The app's privacy manifest declares NSPrivacyTracking = false and an empty NSPrivacyTrackingDomains array.")

            H2("Resetting your data")
            P("Settings → Reset Présage erases every prediction, snapshot, training answer, flashcard, template, AI history, and Spotlight index entry from this device. If iCloud sync was on, the next sync propagates the deletion to your other devices.")
        }
    }
}

private struct AccessibilityArticle: View {
    var body: some View {
        ArticleScroll("Accessibility") {
            H2("VoiceOver")
            P("Every interactive element has an accessibility label or implicit one via SwiftUI's Label component. The Home screen reads in priority order: Brier hero → quick stats → resolving soon → calibration curve, so the most important number is heard first.")

            H2("Confidence dial")
            P("The dial exposes a value of \"N percent\" so VoiceOver users hear the current setting and can adjust with the standard rotor.")

            H2("Dynamic Type")
            P("Most text scales with iOS Accessibility text-size settings. Tab bar labels are capped at xLarge to keep the bar usable; everything else scales freely. If a text is clipped at very large sizes, that's a bug — please report.")

            H2("Reduced motion")
            P("If 'Reduce Motion' is enabled in iOS Settings → Accessibility → Motion, Présage's spring animations on score reveal and tab transitions automatically simplify to crossfades.")

            H2("Color contrast")
            P("The dark theme is the primary experience — text contrast is well above WCAG AA. The light theme uses a darkened accent (#B8882E vs #2FA8A8 for dark) to stay above AA on a cream background. If you find a pairing that fails, report it.")

            H2("Right-to-left languages")
            P("All layouts use SwiftUI's leading/trailing alignment (not left/right), so they mirror automatically when the device language is RTL. Charts mirror their axes appropriately.")

            H2("Haptics")
            P("The confidence dial uses haptic ticks at every 5% increment, heavier at 50/80/95 (the decision boundaries). Resolution outcomes have distinct haptic signatures (success / failure / ambiguous) so you can feel the result without seeing the screen.")

            H2("Keyboard support (iPad)")
            P("Cmd+N opens the new prediction flow. Cmd+R opens Quick Predict. Esc dismisses sheets and covers. Tab navigation traverses interactive elements in source order.")
        }
    }
}

private struct TermsArticle: View {
    var body: some View {
        ArticleScroll("Terms & Conditions") {
            H2("Acceptance")
            P("By using Présage you agree to these terms. They're short and written for humans, not lawyers.")

            H2("Personal use")
            P("Présage is licensed to you for personal, non-commercial use. The Présage for Teams workspace tier is the commercial path; if you're using it for organizational forecasting, that tier applies.")

            H2("No warranty")
            P("Présage is provided as-is. The app is a tool for self-reflection, not financial, medical, legal, or professional advice. Predictions about your own life, even well-calibrated ones, are not a substitute for professional judgment in domains where it matters.")

            H2("Your data is yours")
            P("Everything you create in Présage — predictions, calibration history, exports — belongs to you. We don't claim any rights to it, and we don't have access to it (it lives on your device).")

            H2("AI features and third-party LLMs")
            P("If you bring your own OpenAI or Anthropic API keys, your usage of those services is governed by their respective terms. Présage facilitates the connection but doesn't broker it.")

            H2("App Store")
            P("If you obtained Présage through the App Store, Apple's standard end-user license agreement applies: apple.com/legal/sla.")

            H2("Changes")
            P("Terms may update with new app versions. Substantial changes will be highlighted in release notes.")

            H2("Contact")
            P("Questions about these terms: support@presage.app (or whatever the official contact email is once registered).")
        }
    }
}

private struct AboutArticle: View {
    @Environment(\.colorScheme) private var colorScheme

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        ArticleScroll("About") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Présage")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DS.Palette.textPrimary)
                Text("Version \(version) (build \(build))")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Palette.textSecondary)
            }

            H2("What it is")
            P("A personal calibrated forecasting tool. You predict things about your own life, Présage scores you with proper scoring rules, and the calibration curve shows the gap between confidence and reality.")

            H2("Built with")
            Bullet("SwiftUI", "Every screen is SwiftUI — no UIKit unless unavoidable.")
            Bullet("SwiftData", "Local-first persistence with optional CloudKit sync.")
            Bullet("Swift Charts", "Calibration curves and breakdowns.")
            Bullet("ActivityKit", "Live Activities for active predictions.")
            Bullet("WidgetKit", "Home Screen and Lock Screen widgets.")
            Bullet("App Intents", "Siri shortcuts and Spotlight integration.")
            Bullet("HealthKit", "Optional mood pre-fill from State of Mind entries.")
            Bullet("Foundation Models", "On-device LLM coach (iOS 18+ on supported devices).")

            H2("The math")
            P("Brier score, log score, and calibration bucketing follow the standard formulations from forecasting research — Tetlock's Good Judgment work, Roulston & Smith's reliability diagrams, and the Brier (1950) original. The implementations are pure Swift functions in ScoringEngine, fully unit tested.")

            H2("Acknowledgments")
            P("This app stands on the shoulders of decades of forecasting research. Credit to Phil Tetlock and the Good Judgment Project, the team behind Metaculus, Robin Hanson on prediction markets, Nate Silver on reliability diagrams, and the broader forecasting community whose work makes calibration measurable.")

            H2("Open source")
            P("Présage uses only Apple frameworks. No third-party Swift packages are linked in the production build.")

            H2("Contact")
            P("Bug reports, feature requests, or general feedback: through TestFlight while the app is in beta, or App Store reviews once shipped. Critical security issues: encrypted contact via the developer's PGP key (published once registered).")

            Callout("Présage is a tool to see yourself clearly. Whether the score is humbling or vindicating, the score is the score — and that's the whole point.")
        }
    }
}
