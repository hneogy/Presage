import SwiftUI
import SwiftData
import TipKit
import CoreSpotlight

@main
struct PariApp: App {
    let modelContainer: ModelContainer
    let engine: PariEngine

    init() {
        let container = CloudSyncManager.makeContainer()
        modelContainer = container
        let cache = CalibrationCache(modelContainer: container)
        engine = PariEngine(calibrationCache: cache)

        BackgroundTaskScheduler.register(modelContainer: container)

        if #available(iOS 17.0, *) {
            try? Tips.configure([
                .displayFrequency(.daily),
                .datastoreLocation(.applicationDefault)
            ])
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.willEnterForegroundNotification
                )) { _ in
                    engine.handleForeground(context: modelContainer.mainContext)
                    RecurrenceEngine.spawnDuePredictions(in: modelContainer.mainContext)
                }
                .onOpenURL { url in
                    engine.handleDeepLink(url)
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    engine.handleSpotlight(activity)
                }
                .task {
                    // Wire the notification delegate before requesting
                    // permission so we never miss the first tap.
                    PariNotificationDelegate.shared.routeHandler = { url in
                        engine.handleDeepLink(url)
                    }
                    PariNotificationDelegate.shared.register()

                    BackgroundTaskScheduler.schedule()
                    _ = await NotificationScheduler.shared.requestPermission()
                    TrainingPack.seedIfNeeded(in: modelContainer.mainContext)
                    RecurrenceEngine.spawnDuePredictions(in: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("predictionCount") private var predictionCount = 0
    @AppStorage("preferredColorScheme") private var preferredScheme = 0

    var body: some View {
        Group {
            // Onboarding is "done" if either the user finished it
            // explicitly OR they have at least one prediction. The
            // second condition rescues the edge case where the user
            // saved their first prediction during onboarding and then
            // force-quit before tapping "Show me Pari" — without it,
            // they'd be forced through onboarding again, ending up
            // with two "first" predictions.
            if hasCompletedOnboarding || predictionCount > 0 {
                RootTabView()
            } else {
                OnboardingFlow()
            }
        }
        .preferredColorScheme(globalScheme)
    }

    /// Lifted to the root so the theme switch in Settings affects the
    /// entire app, not just the Settings sheet itself. Was a silent bug
    /// where the toggle did nothing visible after dismiss.
    private var globalScheme: ColorScheme? {
        switch preferredScheme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}
