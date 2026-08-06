import SwiftUI

@main
struct SarjBulApp: App {
    @UIApplicationDelegateAdaptor(SarjBulAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    private let appState: AppState
    @State private var routeStore: RouteStore
    @State private var networkMonitor: NetworkMonitor

    init() {
        FirebaseBootstrap.configureIfAvailable()
        appState = AppState.bootstrap()
        _routeStore = State(initialValue: RouteStore())
        _networkMonitor = State(initialValue: NetworkMonitor())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState.messages)
                .environment(appState.settings)
                .environment(appState.auth)
                .environment(appState.stationData)
                .environment(appState.favorites)
                .environment(appState.search)
                .environment(appState.navigation)
                .environment(appState.deepLinks)
                .environment(appState.lounge)
                .environment(appState.chargingHistory)
                .environment(appState.chargingSession)
                .environment(appState.habits)
                .environment(appState.autonomousAgent)
                .environment(routeStore)
                .environment(networkMonitor)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background, appState.settings.autonomousChargingPolicy.isEnabled else { return }
            AutonomousBackgroundScheduler.schedule()
        }
        .backgroundTask(.appRefresh(AutonomousBackgroundScheduler.identifier)) {
            await appState.search.prepare()
            await appState.autonomousAgent.refreshInBackground()
        }
    }
}
