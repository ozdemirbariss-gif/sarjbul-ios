import Foundation
import SarjBulCore

@MainActor
final class AppState {
    let messages: AppMessagePresenter
    let settings: UserSettingsStore
    let auth: AuthStore
    let stationData: StationDataStore
    let favorites: FavoritesStore
    let search: SearchCoordinator
    let navigation: NavigationCoordinator
    let deepLinks: DeepLinkRouter
    let lounge: LoungeStore
    let chargingHistory: ChargingHistoryStore
    let chargingSession: ChargingSessionStore
    let habits: HabitStore
    let autonomousAgent: AutonomousChargingAgentStore

    init(
        repository: any StationRepository,
        clients: AppServiceClients,
        persistence: any AppPersistence,
        externalLinks: AppExternalLinks,
        vehicleTelemetryClient: any VehicleTelemetryClient = ProfileVehicleTelemetryClient()
    ) {
        let messages = AppMessagePresenter()
        let settings = UserSettingsStore(persistence: persistence, externalLinks: externalLinks)
        let navigation = NavigationCoordinator()
        let mutationQueue = AsyncMutationQueue()
        let auth = AuthStore(
            client: clients.auth,
            persistence: persistence,
            messages: messages,
            isConfigured: clients.isConfigured
        )
        let pipeline = StationDataPipeline(
            repository: repository,
            statusClient: clients.status,
            liveAvailabilityClient: clients.liveAvailability
        )
        let stationData = StationDataStore(
            pipeline: pipeline,
            statusClient: clients.status,
            realtimeClient: clients.realtime,
            mutationQueue: mutationQueue,
            persistence: persistence,
            messages: messages
        )
        let favorites = FavoritesStore(
            client: clients.favorites,
            auth: auth,
            stationData: stationData,
            mutationQueue: mutationQueue,
            persistence: persistence,
            messages: messages
        )
        let habits = HabitStore(persistence: persistence)
        let search = SearchCoordinator(
            stationData: stationData,
            settings: settings,
            favorites: favorites,
            auth: auth,
            navigation: navigation,
            messages: messages,
            habits: habits,
            demandAnalytics: clients.demandAnalytics,
            mutationQueue: mutationQueue
        )

        self.messages = messages
        self.settings = settings
        self.auth = auth
        self.stationData = stationData
        self.favorites = favorites
        self.search = search
        self.navigation = navigation
        self.habits = habits
        autonomousAgent = AutonomousChargingAgentStore(
            stationData: stationData,
            settings: settings,
            search: search,
            persistence: persistence,
            telemetryClient: vehicleTelemetryClient
        )
        deepLinks = DeepLinkRouter(search: search, navigation: navigation)
        lounge = LoungeStore(persistence: persistence)
        chargingHistory = ChargingHistoryStore(persistence: persistence)
        chargingSession = ChargingSessionStore(persistence: persistence)

        stationData.onRealtimeEvent = { [weak search] event in
            search?.applyRealtime(event)
        }
        auth.onSessionChanged = { [weak favorites, weak stationData] session in
            await favorites?.handleSessionChanged(session)
            await stationData?.reloadCommunityData(idToken: session?.idToken)
            stationData?.startRealtime(idToken: session?.idToken)
        }
        applyDebugLaunchMode()
    }

    static func bootstrap() -> AppState {
        let config = AppConfiguration.load()
        let links = AppExternalLinks(
            privacyPolicyURL: config.privacyPolicyURL,
            termsOfUseURL: config.termsOfUseURL,
            supportURL: config.supportURL,
            supportEmail: config.supportEmail
        )
        let repository: any StationRepository
        let clients: AppServiceClients
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-routes")
            || ProcessInfo.processInfo.arguments.contains("--ui-testing-agent") {
            repository = UITestStationRepository()
            clients = AppServiceClients(
                auth: UnavailableAuthClient(),
                favorites: UnavailableFavoritesClient(),
                status: UnavailableStatusClient(),
                demandAnalytics: UnavailableDemandAnalyticsClient(),
                realtime: UnavailableRealtimeStationClient(),
                liveAvailability: UnavailableLiveAvailabilityClient(),
                isConfigured: false
            )
        } else {
            repository = config.stationRepository() ?? EmptyStationRepository()
            clients = config.serviceClients
        }
        #else
        repository = config.stationRepository() ?? EmptyStationRepository()
        clients = config.serviceClients
        #endif
        return AppState(
            repository: repository,
            clients: clients,
            persistence: SystemAppPersistence(),
            externalLinks: links
        )
    }

    private func applyDebugLaunchMode() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing-device-location") {
            navigation.tab = .home
            search.userLocation = UserLocation(latitude: 38.3939, longitude: 27.1891, source: .device)
        } else if arguments.contains("--ui-testing-home")
                    || arguments.contains("--ui-testing-routes")
                    || arguments.contains("--ui-testing-habit")
                    || arguments.contains("--ui-testing-agent")
                    || arguments.contains("--ui-testing-context-critical") {
            navigation.tab = .home
            settings.destination = nil
            settings.filters = StationFilters(rangeFilterEnabled: false)
            search.userLocation = UserLocation(latitude: 38.3939, longitude: 27.1891, source: .manual)
            if arguments.contains("--ui-testing-habit") {
                seedHabitSuggestionForUITesting()
            }
            if arguments.contains("--ui-testing-context-critical") {
                settings.profile.chargePercent = 15
            }
            if arguments.contains("--ui-testing-agent") {
                autonomousAgent.resetForUITesting()
                settings.profile.chargePercent = 20
                var policy = settings.autonomousChargingPolicy
                policy.isEnabled = true
                policy.minimumStationScore = 1
                settings.autonomousChargingPolicy = policy
            }
        } else if arguments.contains("--ui-testing-lounge") {
            navigation.tab = .lounge
        } else if arguments.contains("--ui-testing-profile") {
            navigation.tab = .account
        }
        #endif
    }

    #if DEBUG
    private func seedHabitSuggestionForUITesting() {
        let station = Station(
            id: "habit-test-station",
            name: "Alsancak Hızlı Şarj",
            address: "Konak, İzmir",
            latitude: 38.4382,
            longitude: 27.1434,
            power: "180 kW",
            operatorName: "ŞarjBul",
            socket: "CCS2",
            price: "Bilinmiyor",
            source: "ui-test"
        )
        for day in 1...3 {
            habits.recordRouteOpened(station, at: Date().addingTimeInterval(-Double(day) * 86_400))
        }
    }
    #endif
}

private struct EmptyStationRepository: StationRepository {
    func loadStations() async throws -> [Station] {
        throw StationRepositoryError.missingResource
    }
}

#if DEBUG
private struct UITestStationRepository: StationRepository {
    func loadStations() async throws -> [Station] {
        [
            Station(
                id: "ui-test-station",
                name: "Buca Belediyesi Yedigöller Cafe",
                address: "Buca, İzmir",
                latitude: 38.4002,
                longitude: 27.1814,
                power: "180 kW",
                operatorName: "wat mobilite",
                socket: "CCS2",
                price: "8,90 TL/kWh",
                source: "ui-test",
                confidenceScore: 0.94
            )
        ]
    }
}
#endif
