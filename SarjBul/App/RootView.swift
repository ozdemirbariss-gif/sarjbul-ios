import SwiftUI

struct RootView: View {
    @Environment(AppMessagePresenter.self) private var messages
    @Environment(UserSettingsStore.self) private var settings
    @Environment(StationDataStore.self) private var stationData
    @Environment(SearchCoordinator.self) private var search
    @Environment(NavigationCoordinator.self) private var navigation
    @Environment(DeepLinkRouter.self) private var deepLinks
    @Environment(NetworkMonitor.self) private var networkMonitor
    @State private var bottomNavigationExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            currentScreen
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !networkMonitor.isConnected {
                        offlineBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: bottomInsetHeight)
                }

            if showsBottomNavigation {
                bottomNavigation
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .tint(SBColor.accent)
        .preferredColorScheme(.light)
        .task {
            await search.prepare()
            guard PendingAppIntentStore.consume() == .nearestFast else { return }
            settings.filters.preference = .fastest
            navigation.select(.home)
            if search.userLocation != nil { await search.findStations() }
        }
        .sensoryFeedback(.selection, trigger: navigation.tab)
        .onChange(of: navigation.tab) { _, tab in
            guard tab != .account else { return }
            bottomNavigationExpanded = false
        }
        .onOpenURL { url in
            Task { await deepLinks.handle(url) }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: networkMonitor.isConnected)
        .alert(messageTitle, isPresented: Binding(
            get: { messages.current != nil },
            set: { if !$0 { messages.dismiss() } }
        )) {
            if stationData.canRetryLoad {
                Button(settings.t("data.refresh")) {
                    Task { await search.retryLoad() }
                }
            }
            Button(settings.t("status.ok"), role: .cancel) {}
        } message: {
            Text(messages.current?.text(language: settings.language) ?? "")
        }
    }

    private var offlineBanner: some View {
        Label(settings.t("network.offline"), systemImage: "wifi.slash")
            .font(.caption.weight(.heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 34)
            .background(SBColor.electricBlue)
            .accessibilityAddTraits(.isStaticText)
    }

    private var bottomInsetHeight: CGFloat {
        guard showsBottomNavigation else { return 0 }
        return bottomNavigationExpanded ? 118 : 28
    }

    private var showsBottomNavigation: Bool {
        navigation.tab == .home || navigation.tab == .lounge
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch navigation.tab {
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
        .sbPremiumGlass(radius: 36, interactive: true)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .shadow(color: SBColor.electricBlue.opacity(0.16), radius: 24, x: 0, y: 16)
    }

    private var collapsedBottomNavigation: some View {
        Button {
            Haptic.tap()
            if reduceMotion {
                bottomNavigationExpanded = true
            } else {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    bottomNavigationExpanded = true
                }
            }
        } label: {
            Image(systemName: "square.grid.2x2.fill")
                .font(.headline.weight(.heavy))
                .symbolEffect(.bounce, value: navigation.tab)
            .foregroundStyle(SBColor.ink)
            .frame(width: 54, height: 54)
            .sbPremiumGlass(radius: 27, interactive: true)
            .shadow(color: SBColor.electricBlue.opacity(0.14), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(SBPremiumButtonStyle())
        .accessibilityLabel(settings.t("navigation.open"))
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 18)
        .padding(.bottom, 14)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = navigation.tab == tab
        return Button {
            Haptic.tap()
            if reduceMotion {
                navigation.tab = tab
                bottomNavigationExpanded = false
            } else {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                    navigation.tab = tab
                    bottomNavigationExpanded = false
                }
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tabIcon(tab))
                    .font(.headline.weight(.heavy))
                    .frame(height: 18)
                    .symbolEffect(.bounce, value: isSelected)
                Text(tabTitle(tab))
                    .font(.caption2.weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .allowsTightening(true)
            }
            .foregroundStyle(isSelected ? .white : SBColor.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(isSelected ? SBColor.electricBlue : SBColor.surface.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? SBColor.lineStrong : SBColor.line, lineWidth: 1)
            )
        }
        .buttonStyle(SBPremiumButtonStyle())
    }

    private func tabTitle(_ tab: AppTab) -> String {
        switch tab {
        case .home:
            settings.t("bottom.home")
        case .lounge:
            settings.t("bottom.map")
        case .routes:
            settings.t("bottom.routes")
        case .account:
            settings.t("bottom.account")
        }
    }

    private func tabIcon(_ tab: AppTab) -> String {
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

    private var messageTitle: String {
        messages.current?.kind == .success ? settings.t("status.ok") : settings.t("status.error")
    }
}
