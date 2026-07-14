import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var bottomNavigationExpanded = false

    var body: some View {
        ZStack(alignment: .bottom) {
            currentScreen
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: bottomInsetHeight)
                }

            if appState.tab != .account {
                bottomNavigation
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .tint(SBColor.accent)
        .preferredColorScheme(.light)
        .task { await appState.load() }
        .onChange(of: appState.tab) { _, tab in
            guard tab != .account else { return }
            bottomNavigationExpanded = false
        }
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

    private var bottomInsetHeight: CGFloat {
        guard appState.tab != .account else { return 0 }
        return bottomNavigationExpanded ? 118 : 76
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

    @ViewBuilder
    private var bottomNavigation: some View {
        if bottomNavigationExpanded {
            expandedBottomNavigation
                .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.96)))
        } else {
            collapsedBottomNavigation
                .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.92)))
        }
    }

    private var expandedBottomNavigation: some View {
        HStack(spacing: 8) {
            tabButton(.home)
            tabButton(.lounge)
            tabButton(.routes)
            tabButton(.account)
        }
        .padding(8)
        .background(
            Capsule()
                .fill(SBColor.glassStrong.opacity(0.96))
                .overlay(
                    Capsule()
                        .stroke(SBColor.line, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .shadow(color: SBColor.electricBlue.opacity(0.16), radius: 24, x: 0, y: 16)
    }

    private var collapsedBottomNavigation: some View {
        Button {
            Haptic.tap()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                bottomNavigationExpanded = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: currentTabIcon)
                    .font(.headline.weight(.heavy))
                Text(currentTabTitle)
                    .font(.subheadline.weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Image(systemName: "chevron.up")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(SBColor.muted)
            }
            .foregroundStyle(SBColor.ink)
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(SBColor.glassStrong.opacity(0.98))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(SBColor.line, lineWidth: 1)
            )
            .shadow(color: SBColor.electricBlue.opacity(0.14), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 14)
    }

    private func tabButton(_ tab: AppState.Tab) -> some View {
        let isSelected = appState.tab == tab
        return Button {
            Haptic.tap()
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                appState.tab = tab
                bottomNavigationExpanded = false
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tabIcon(tab))
                    .font(.headline.weight(.heavy))
                    .frame(height: 18)
                Text(tabTitle(tab))
                    .font(.caption2.weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .allowsTightening(true)
            }
            .foregroundStyle(isSelected ? .white : SBColor.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(isSelected ? SBColor.electricBlue : SBColor.surface.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? SBColor.lineStrong : SBColor.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var currentTabTitle: String {
        tabTitle(appState.tab)
    }

    private var currentTabIcon: String {
        tabIcon(appState.tab)
    }

    private func tabTitle(_ tab: AppState.Tab) -> String {
        switch tab {
        case .home:
            appState.t("bottom.home")
        case .lounge:
            appState.t("bottom.map")
        case .routes:
            appState.t("bottom.routes")
        case .account:
            appState.t("bottom.account")
        }
    }

    private func tabIcon(_ tab: AppState.Tab) -> String {
        switch tab {
        case .home:
            "house"
        case .lounge:
            "gamecontroller"
        case .routes:
            "point.topleft.down.curvedto.point.bottomright.up"
        case .account:
            "person"
        }
    }
}
