import SwiftUI
import UIKit
import AuthenticationServices

struct SettingsSheet: View {
    @Environment(PariEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("preferredColorScheme") private var preferredScheme = 0
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = false
    @AppStorage("healthKitMoodEnabled") private var healthKitEnabled = false
    @AppStorage("spotlightIndexingEnabled") private var spotlightIndexingEnabled = true
    @AppStorage("notificationPreviewsEnabled") private var notificationPreviewsEnabled = true
    @AppStorage(PariSharedStore.appGroupFallbackFlagKey) private var widgetSyncBroken = false
    @State private var showRestartAlert = false
    @State private var showEraseConfirm = false
    @State private var showHealthKitDeniedAlert = false

    var body: some View {
        List {
            Section("Appearance") {
                Picker("Theme", selection: $preferredScheme) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(.segmented)
                .listRowBackground(DS.Palette.surfaceSecondary)
            }

            Section("Notifications") {
                Button {
                    Task { _ = await NotificationScheduler.shared.requestPermission() }
                } label: {
                    Label("Enable resolution reminders", systemImage: "bell")
                }
                .foregroundStyle(DS.Palette.accent)
                .listRowBackground(DS.Palette.surfaceSecondary)
            }

            if widgetSyncBroken {
                Section {
                    HStack(alignment: .top, spacing: DS.Space.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(DS.Palette.accentSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Widgets aren't syncing")
                                .font(.subheadline.weight(.semibold))
                            Text("The shared App Group container couldn't be opened. Reinstall to restore widget data.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(DS.Palette.surfaceSecondary)
                }
            }

            Section {
                Toggle(isOn: $cloudSyncEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iCloud Sync")
                            Text("Off by default. Restart required after change.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "icloud")
                    }
                }
                .listRowBackground(DS.Palette.surfaceSecondary)
                .onChange(of: cloudSyncEnabled) { _, _ in
                    // The ModelContainer is built once at app launch. Switching
                    // CloudKit on/off has no effect until next launch. Rather
                    // than silently failing, prompt the user to restart.
                    showRestartAlert = true
                }

                if cloudSyncEnabled {
                    AppleSignInButton { result in
                        if case .success(let auth) = result {
                            AppleSignInManager.shared.handleAuthorization(auth)
                        }
                    }
                    .listRowBackground(DS.Palette.surfaceSecondary)
                }
            } header: {
                Text("Sync")
            } footer: {
                Text("Présage is private by default. Sync introduces resolution-fudging risk; only enable if you need cross-device.")
            }

            Section {
                Toggle(isOn: $healthKitEnabled) {
                    Label("Mood from Health", systemImage: "heart")
                }
                .listRowBackground(DS.Palette.surfaceSecondary)
                .onChange(of: healthKitEnabled) { _, newValue in
                    guard newValue else { return }
                    // Only prompt the first time. If the user previously
                    // denied, iOS won't re-prompt — explain that and link
                    // them to system Settings rather than silently no-op.
                    let alreadyRequested = UserDefaults.standard.bool(forKey: "healthKitAuthRequested")
                    if !alreadyRequested {
                        Task {
                            _ = await HealthKitMoodSync.shared.requestAuthorization()
                            UserDefaults.standard.set(true, forKey: "healthKitAuthRequested")
                        }
                    } else {
                        showHealthKitDeniedAlert = true
                    }
                }
            } header: {
                Text("Health")
            } footer: {
                Text("Pre-fill mood when creating predictions, on-device only.")
            }

            Section {
                Toggle(isOn: $spotlightIndexingEnabled) {
                    Label("Search predictions in Spotlight", systemImage: "magnifyingglass")
                }
                .listRowBackground(DS.Palette.surfaceSecondary)
                .onChange(of: spotlightIndexingEnabled) { _, newValue in
                    if !newValue {
                        // User just turned indexing off — purge what we
                        // already wrote so a sensitive claim doesn't keep
                        // surfacing in Spotlight after they opted out.
                        Task { await SpotlightIndexer.purgeAllIndexedContent() }
                    }
                }

                Toggle(isOn: $notificationPreviewsEnabled) {
                    Label("Show claim preview in notifications", systemImage: "lock.shield")
                }
                .listRowBackground(DS.Palette.surfaceSecondary)
            } header: {
                Text("Privacy")
            } footer: {
                Text("Spotlight indexes the full claim and criteria. Notification previews include the first 50 characters of the claim on the lock screen. Disable either if your predictions are sensitive.")
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(DS.Palette.textSecondary)
                }
                .listRowBackground(DS.Palette.surfaceSecondary)

                HStack {
                    Text("All data stays on your device")
                    Spacer()
                    Image(systemName: "lock.shield")
                        .foregroundStyle(DS.Palette.semanticYes)
                }
                .listRowBackground(DS.Palette.surfaceSecondary)

                if let devURL = URL(string: "https://neogy.dev/") {
                    Link(destination: devURL) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Developer")
                                    .foregroundStyle(DS.Palette.textPrimary)
                                Text("Honorius M. Neogy (The Honorius M. Neogy)")
                                    .font(.caption)
                                    .foregroundStyle(DS.Palette.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(DS.Palette.accent)
                        }
                    }
                    .listRowBackground(DS.Palette.surfaceSecondary)
                } else {
                    // Hardcoded URL is well-formed today — this branch
                    // exists so a future typo can't crash the row by
                    // landing on `URL(fileURLWithPath: "/")`.
                    HStack {
                        Text("Developer")
                            .foregroundStyle(DS.Palette.textPrimary)
                        Spacer()
                        Text("Honorius M. Neogy")
                            .font(.caption)
                            .foregroundStyle(DS.Palette.textSecondary)
                    }
                    .listRowBackground(DS.Palette.surfaceSecondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    showEraseConfirm = true
                } label: {
                    Label("Reset Présage", systemImage: "trash.slash")
                }
                .listRowBackground(DS.Palette.surfaceSecondary)
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("Erases every prediction, snapshot, training answer, flashcard, and AI score. Restarts onboarding. This cannot be undone.")
            }

            // Spacer row so the Danger Zone footer can scroll above the
            // floating custom tab bar + FAB (~110pt of overlay at the
            // bottom). Without this, "Reset Présage" sits clipped behind
            // the bar even at maximum scroll.
            Section {
                Color.clear
                    .frame(height: 120)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Palette.surfacePrimary)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        // Theme is now applied at RootView so the toggle takes effect
        // app-wide, not just inside this sheet.
        .alert("Restart Présage to apply", isPresented: $showRestartAlert) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("iCloud sync changes take effect after Présage is force-quit and reopened.")
        }
        .alert("Reset Présage?", isPresented: $showEraseConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Erase Everything", role: .destructive) {
                engine.eraseAllData(in: context)
                dismiss()
            }
        } message: {
            Text("This deletes every prediction and resets onboarding. There is no undo.")
        }
        .alert("Health permission previously set", isPresented: $showHealthKitDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                healthKitEnabled = false
            }
        } message: {
            Text("iOS won't re-prompt for Health access once you've answered. Adjust Présage's permissions in Settings → Privacy → Health.")
        }
    }

}
