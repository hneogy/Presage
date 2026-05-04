import SwiftUI
import AuthenticationServices

struct SettingsSheet: View {
    @Environment(PariEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("preferredColorScheme") private var preferredScheme = 0
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = false
    @AppStorage("healthKitMoodEnabled") private var healthKitEnabled = false
    @State private var showRestartAlert = false
    @State private var showEraseConfirm = false

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
                    // Only prompt the first time the toggle is turned on.
                    // After that, the system already remembers the user's
                    // choice; toggling on/off shouldn't keep re-prompting.
                    let alreadyRequested = UserDefaults.standard.bool(forKey: "healthKitAuthRequested")
                    if newValue && !alreadyRequested {
                        Task {
                            _ = await HealthKitMoodSync.shared.requestAuthorization()
                            UserDefaults.standard.set(true, forKey: "healthKitAuthRequested")
                        }
                    }
                }
            } header: {
                Text("Health")
            } footer: {
                Text("Pre-fill mood when creating predictions, on-device only.")
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

                Link(destination: URL(string: "https://neogy.dev/")!) {
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
    }

}
