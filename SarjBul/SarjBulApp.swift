import SwiftUI

@main
struct SarjBulApp: App {
    @State private var appState = AppState.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}
