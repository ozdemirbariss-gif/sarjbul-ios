import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack(alignment: .bottom) {
            currentScreen
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: appState.tab == .account ? 0 : 112)
                }

            if appState.tab != .account {
                bottomNavigation
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .tint(SBColor.accent)
        .preferredColorScheme(.light)
        .task { await appState.load() }
        .alert(appState.messageTitle, isPresented: Binding(
            get: { appState.message != nil },
            set: { if !$0 { appState.dismissMessage() } }
        )) {
            if appState.canRetryStationLoad {
                Button(appState.t("data.refresh")) {
                    Task { await appState.retryLoad() }
                }
            }
            Button(appState.t("status.ok"), role: .cancel) {}
        } message: {
            Text(appState.message ?? "")
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch appState.tab {
        case .home:
            HomeView()
        case .lounge:
            WaitingLoungeView()
        case .routes:
            StationFeedView()
        case .account:
            AccountView()
        }
    }

    private var bottomNavigation: some View {
        HStack(spacing: 8) {
            tabButton(.home, title: appState.t("bottom.home"), icon: "house")
            tabButton(.lounge, title: appState.t("bottom.map"), icon: "gamecontroller")
            tabButton(.routes, title: appState.t("bottom.routes"), icon: "point.topleft.down.curvedto.point.bottomright.up")
            tabButton(.account, title: appState.t("bottom.account"), icon: "person")
        }
        .padding(10)
        .background(SBColor.electricBlue.opacity(0.92))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(SBColor.lineStrong, lineWidth: 1)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
        .sbCardShadow()
    }

    private func tabButton(_ tab: AppState.Tab, title: String, icon: String) -> some View {
        let isSelected = appState.tab == tab
        return Button {
            Haptic.tap()
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                appState.tab = tab
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                Text(title)
                    .font(.subheadline.weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(isSelected ? SBColor.ink : SBColor.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(isSelected ? SBColor.surface : SBColor.glassStrong)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? SBColor.lineStrong : SBColor.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
