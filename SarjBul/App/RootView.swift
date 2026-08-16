import SwiftUI

struct RootView: View {
    @Environment(AppMessagePresenter.self) private var messages
    @Environment(UserSettingsStore.self) private var settings
    @Environment(StationDataStore.self) private var stationData
    @Environment(SearchCoordinator.self) private var search
    @Environment(NavigationCoordinator.self) private var navigation
    @Environment(DeepLinkRouter.self) private var deepLinks
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(RouteStore.self) private var routeStore
    @Environment(ChargingSessionStore.self) private var chargingSession
    @Environment(AutonomousChargingAgentStore.self) private var autonomousAgent
    @Environment(ContextIntelligenceStore.self) private var contextIntelligence
    @Environment(OfflineSyncCoordinator.self) private var offlineSync
    @State private var didSetInitialTab = false
    @State private var isBottomNavigationExpanded = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            currentScreen
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !networkMonitor.isConnected {
                        offlineBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else if offlineSync.isReadOnlySafeMode {
                        safeModeBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if showsBottomNavigation {
                        bottomNavigation
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
        }
        .tint(SBColor.signal)
        .environment(\.locale, settings.language.locale)
        .preferredColorScheme(.dark)
        .task {
            setInitialTabIfNeeded()
            await chargingSession.prepare()
            await search.prepare()
            await offlineSync.syncPending()
            await autonomousAgent.evaluate(
                trigger: .appLaunch,
                location: search.userLocation
            )
            await contextIntelligence.evaluate(location: search.userLocation)
            await autonomousAgent.openPendingRouteIfNeeded()
            guard PendingAppIntentStore.consume() == .nearestFast else { return }
            await search.openNearestFast()
        }
        .onReceive(NotificationCenter.default.publisher(for: PendingAutonomousRouteStore.didChange)) { _ in
            Task { await autonomousAgent.openPendingRouteIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: PendingAutonomousRouteStore.didMute)) { _ in
            autonomousAgent.handleMutedNotificationAction()
        }
        .onChange(of: networkMonitor.isConnected) { wasConnected, isConnected in
            if !wasConnected && isConnected {
                routeStore.invalidate()
                Task { await offlineSync.syncPending() }
            }
        }
        .sensoryFeedback(.selection, trigger: navigation.tab)
        .onChange(of: navigation.tab) { _, _ in
            guard didSetInitialTab else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.20)) {
                isBottomNavigationExpanded = false
            }
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
            .foregroundStyle(SBColor.onSignal)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 34)
            .background(SBColor.signal)
            .accessibilityAddTraits(.isStaticText)
    }

    private var safeModeBanner: some View {
        Label(settings.t("recovery.safe_mode"), systemImage: "shield.lefthalf.filled")
            .font(.caption.weight(.heavy))
            .foregroundStyle(SBColor.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 34)
            .background(SBColor.surface)
            .accessibilityAddTraits(.isStaticText)
    }

    private var showsBottomNavigation: Bool {
        true
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
        Group {
            if isBottomNavigationExpanded {
                expandedBottomNavigation
            } else {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) {
                            isBottomNavigationExpanded = true
                        }
                    } label: {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(SBColor.onSignal)
                            .frame(width: 54, height: 54)
                            .background(SBColor.signal, in: Circle())
                            .overlay(Circle().stroke(SBColor.line, lineWidth: 1))
                            .shadow(color: .black.opacity(0.42), radius: 18, y: 10)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(settings.t("navigation.open"))
                    .accessibilityIdentifier("bottom-navigation-reveal")
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.96)))
    }

    private var expandedBottomNavigation: some View {
        HStack(spacing: 8) {
            tabButton(.home)
            tabButton(.routes)
            tabButton(.lounge)
            tabButton(.account)
        }
        .padding(7)
        .background(SBColor.charcoal.opacity(0.98), in: Capsule())
        .overlay(Capsule().stroke(SBColor.line, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .shadow(color: .black.opacity(0.54), radius: 26, x: 0, y: 16)
    }

    private func setInitialTabIfNeeded() {
        guard !didSetInitialTab else { return }
        didSetInitialTab = true

        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let forcedPreview = arguments.contains { argument in
            argument.hasPrefix("--ui-testing-") && argument != "--ui-testing-default-launch"
        }
        guard !forcedPreview else { return }
        #endif

        navigation.select(.home)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = navigation.tab == tab
        let selectedColor = tab == .lounge ? SBColor.loungeAccent : SBColor.signal
        return Button {
            Haptic.tap()
            if reduceMotion {
                navigation.tab = tab
            } else {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                    navigation.tab = tab
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: tabIcon(tab))
                    .font(.headline.weight(.heavy))
                    .frame(width: 20, height: 20)
                    .symbolEffect(.bounce, value: isSelected)
                if isSelected {
                    Text(tabTitle(tab))
                        .font(.caption.weight(.heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
            }
            .foregroundStyle(isSelected ? SBColor.onSignal : SBColor.textSoft)
            .padding(.horizontal, isSelected ? 14 : 0)
            .frame(minWidth: 50, maxWidth: isSelected ? .infinity : 50)
            .frame(height: 54)
            .background(isSelected ? selectedColor : SBColor.surface.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? .black.opacity(0.12) : SBColor.line, lineWidth: 1)
            )
        }
        .buttonStyle(SBPremiumButtonStyle())
        .accessibilityLabel(tabTitle(tab))
        .accessibilityIdentifier("bottom-navigation-tab-\(tabIdentifier(tab))")
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

    private func tabIdentifier(_ tab: AppTab) -> String {
        switch tab {
        case .home: "home"
        case .lounge: "lounge"
        case .routes: "routes"
        case .account: "account"
        }
    }

    private var messageTitle: String {
        messages.current?.kind == .success ? settings.t("status.ok") : settings.t("status.error")
    }
}
