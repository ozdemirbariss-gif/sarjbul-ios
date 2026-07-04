import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.tab) {
            HomeView()
                .tabItem { Label("Ana Sayfa", systemImage: "house.fill") }
                .tag(AppState.Tab.home)

            StationFeedView()
                .tabItem { Label("Rotalar", systemImage: "point.topleft.down.curvedto.point.bottomright.up") }
                .tag(AppState.Tab.routes)

            WaitingLoungeView()
                .tabItem { Label("Salon", systemImage: "gamecontroller.fill") }
                .tag(AppState.Tab.lounge)

            AccountView()
                .tabItem { Label("Hesap", systemImage: "person.fill") }
                .tag(AppState.Tab.account)
        }
        .tint(SBColor.accent)
        .task { appState.load() }
    }
}

