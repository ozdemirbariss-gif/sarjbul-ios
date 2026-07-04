import SwiftUI

@main
struct SarjBulApp: App {
    @StateObject private var appState = AppState.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

