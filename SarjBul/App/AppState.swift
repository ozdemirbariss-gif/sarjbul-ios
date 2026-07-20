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

    init(
        repository: any StationRepository,
        clients: AppServiceClients,
        persistence: any AppPersistence,
        externalLinks: AppExternalLinks
    ) {
        let messages = AppMessagePresenter()
        let settings = UserSettingsStore(persistence: persistence, externalLinks: externalLinks)
        let navigation = NavigationCoordinator()
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
            persistence: persistence,
            messages: messages
        )
        let favorites = FavoritesStore(
            client: clients.favorites,
            auth: auth,
            stationData: stationData,
            persistence: persistence,
            messages: messages
        )
        let search = SearchCoordinator(
            stationData: stationData,
            settings: settings,
            favorites: favorites,
            auth: auth,
            navigation: navigation,
            messages: messages,
            demandAnalytics: clients.demandAnalytics
        )

        self.messages = messages
        self.settings = settings
        self.auth = auth
        self.stationData = stationData
        self.favorites = favorites
        self.search = search
        self.navigation = navigation
        deepLinks = DeepLinkRouter(search: search, navigation: navigation)
        lounge = LoungeStore(persistence: persistence)
        chargingHistory = ChargingHistoryStore(persistence: persistence)
        chargingSession = ChargingSessionStore()

        auth.onSessionChanged = { [weak favorites, weak stationData] session in
            await favorites?.handleSessionChanged(session)
            await stationData?.reloadCommunityData(idToken: session?.idToken)
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
        return AppState(
            repository: config.stationRepository() ?? EmptyStationRepository(),
            clients: config.serviceClients,
            persistence: SystemAppPersistence(),
            externalLinks: links
        )
    }

    private func applyDebugLaunchMode() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing-home") || arguments.contains("--ui-testing-routes") {
            navigation.tab = .home
            search.userLocation = UserLocation(latitude: 38.3939, longitude: 27.1891, source: .manual)
        } else if arguments.contains("--ui-testing-lounge") {
            navigation.tab = .lounge
        }
        #endif
    }
}

private struct EmptyStationRepository: StationRepository {
    func loadStations() async throws -> [Station] {
        throw StationRepositoryError.missingResource
    }
}
