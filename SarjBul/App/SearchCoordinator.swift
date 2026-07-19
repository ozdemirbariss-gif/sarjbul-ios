import Observation
import SarjBulCore
import SwiftUI

enum SearchState: Sendable {
    case idle
    case searching
    case results([StationCandidate])
    case failed(AppMessage)

    var isSearching: Bool {
        if case .searching = self { return true }
        return false
    }

    var candidates: [StationCandidate] {
        if case .results(let candidates) = self { return candidates }
        return []
    }
}

@MainActor
@Observable
final class SearchCoordinator {
    private let stationData: StationDataStore
    private let settings: UserSettingsStore
    private let favorites: FavoritesStore
    private let auth: AuthStore
    private let navigation: NavigationCoordinator
    private let messages: AppMessagePresenter
    private let journeyRouteService = JourneyRouteService()
    private var pendingStationKey: String?
    private var prepared = false

    var userLocation: UserLocation?
    var state: SearchState = .idle

    init(
        stationData: StationDataStore,
        settings: UserSettingsStore,
        favorites: FavoritesStore,
        auth: AuthStore,
        navigation: NavigationCoordinator,
        messages: AppMessagePresenter
    ) {
        self.stationData = stationData
        self.settings = settings
        self.favorites = favorites
        self.auth = auth
        self.navigation = navigation
        self.messages = messages
    }

    var routeCandidates: [StationCandidate] { state.candidates }
    var isSearching: Bool { state.isSearching }
    var canSearch: Bool { userLocation != nil && !stationData.stations.isEmpty && !isSearching }

    func prepare() async {
        guard !prepared else { return }
        prepared = true
        let session = try? await auth.validSession()
        await stationData.load(statusIDToken: session?.idToken)
        if auth.isAuthenticated { await favorites.load() }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-routes") {
            await findStations()
        }
        #endif
    }

    func retryLoad() async {
        let session = try? await auth.validSession()
        await stationData.retry(statusIDToken: session?.idToken)
    }

    func updateLocation(latitude: Double, longitude: Double, source: UserLocation.Source) {
        userLocation = UserLocation(latitude: latitude, longitude: longitude, source: source)
        state = .idle
        if let pendingStationKey {
            self.pendingStationKey = nil
            Task { await openStation(withKey: pendingStationKey) }
        }
    }

    func reset() {
        state = .idle
    }

    func applyFilters(_ filters: StationFilters) async {
        settings.filters = filters
        guard userLocation != nil else { return }
        await findStations()
    }

    func findStations() async {
        guard let userLocation else {
            state = .failed(.localized(key: "route.location_required", kind: .error))
            return
        }

        state = .searching
        let routePoints: [UserLocation]
        if let destination = settings.destination {
            do {
                routePoints = try await journeyRouteService.corridorPoints(
                    origin: userLocation,
                    destination: destination
                )
            } catch {
                routePoints = []
                AppLogger.routing.warning("Journey corridor route failed: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            routePoints = []
        }

        let result = await stationData.candidates(
            origin: userLocation,
            destination: settings.destination,
            routePoints: routePoints,
            profile: settings.profile,
            filters: settings.filters
        )
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            state = .results(result)
            navigation.select(.routes)
        }
    }

    func openStation(withKey key: String) async {
        guard let station = await stationData.station(withKey: key) else {
            messages.present(.localized(key: "deep_link.not_found", kind: .error))
            return
        }
        guard let origin = userLocation else {
            pendingStationKey = key
            navigation.select(.home)
            messages.present(.localized(key: "deep_link.location_needed", kind: .information))
            return
        }

        await findStations()
        var candidates = routeCandidates
        if let index = candidates.firstIndex(where: { $0.station.id == station.id }) {
            candidates.insert(candidates.remove(at: index), at: 0)
        } else {
            var relaxedFilters = settings.filters
            relaxedFilters.rangeFilterEnabled = false
            relaxedFilters.minimumPowerKW = 0
            relaxedFilters.socketFilters = []
            if let direct = await stationData.directCandidate(
                station: station,
                origin: origin,
                profile: settings.profile,
                filters: relaxedFilters
            ) {
                candidates.insert(direct, at: 0)
            }
        }
        state = .results(candidates)
        navigation.select(.routes)
        navigation.push(.station(key: key), on: .routes)
    }
}
