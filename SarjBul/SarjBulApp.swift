import SwiftUI

@main
struct SarjBulApp: App {
    @State private var appState: AppState
    @State private var routeStore: RouteStore
    @State private var networkMonitor: NetworkMonitor

    init() {
        FirebaseBootstrap.configureIfAvailable()
        _appState = State(initialValue: AppState.bootstrap())
        _routeStore = State(initialValue: RouteStore())
        _networkMonitor = State(initialValue: NetworkMonitor())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(routeStore)
                .environment(networkMonitor)
        }
    }
}
