import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView(selection: Binding(
            get: { appState.tab },
            set: { appState.tab = $0 }
        )) {
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
        .preferredColorScheme(.light)
        .task { await appState.load() }
        .alert(appState.messageTitle, isPresented: Binding(
            get: { appState.message != nil },
            set: { if !$0 { appState.dismissMessage() } }
        )) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(appState.message ?? "")
        }
    }
}
