import SwiftUI

@main
struct SarjBulApp: App {
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
                .environment(routeStore)
                .environment(networkMonitor)
        }
    }
}
