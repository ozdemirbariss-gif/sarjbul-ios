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
                await appState.autonomousAgent.handleSilentPush()
            },
            processingHandler: {
                await appState.search.prepare()
                await appState.offlineSync.syncPending()
                await appState.autonomousAgent.processInBackground()
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
                .environment(appState.autonomousAgent)
                .environment(appState.offlineSync)
                .environment(routeStore)
                .environment(networkMonitor)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            AutonomousBackgroundScheduler.scheduleAll()
        }
        .backgroundTask(.appRefresh(AutonomousBackgroundScheduler.refreshIdentifier)) {
            await appState.search.prepare()
            await appState.offlineSync.syncPending()
            await appState.autonomousAgent.refreshInBackground()
        }
    }
}
