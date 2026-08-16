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
        let appState = AppState.bootstrap()
        self.appState = appState
        _routeStore = State(initialValue: RouteStore())
        _networkMonitor = State(initialValue: NetworkMonitor())
        AutonomousBackgroundRuntime.install(
            silentPushHandler: {
                await appState.search.prepare()
                await appState.offlineSync.syncPending()
                let agentSucceeded = await appState.autonomousAgent.handleSilentPush()
                await appState.contextIntelligence.refreshInBackground(
                    location: appState.search.userLocation
                )
                return agentSucceeded && !appState.offlineSync.isReadOnlySafeMode
            },
            processingHandler: {
                await appState.search.prepare()
                await appState.offlineSync.syncPending()
                let agentSucceeded = await appState.autonomousAgent.processInBackground()
                await appState.contextIntelligence.refreshInBackground(
                    location: appState.search.userLocation
                )
                return agentSucceeded && !appState.offlineSync.isReadOnlySafeMode
            }
        )
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
                .environment(appState.executionTrust)
                .environment(appState.frictionTelemetry)
                .environment(appState.autonomousAgent)
                .environment(appState.contextIntelligence)
                .environment(appState.offlineSync)
                .environmentObject(appState.locationManager)
                .environment(routeStore)
                .environment(networkMonitor)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                appState.locationManager.requestFreshLocation()
            } else if phase == .background {
                AutonomousBackgroundScheduler.scheduleAll()
            }
        }
        .backgroundTask(.appRefresh(AutonomousBackgroundScheduler.refreshIdentifier)) {
            await appState.search.prepare()
            await appState.offlineSync.syncPending()
            _ = await appState.autonomousAgent.refreshInBackground()
            await appState.contextIntelligence.refreshInBackground(
                location: appState.search.userLocation
            )
        }
    }
}
