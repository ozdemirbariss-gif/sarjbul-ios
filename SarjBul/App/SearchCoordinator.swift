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
    private let demandAnalytics: any DemandAnalyticsClient
    private let journeyRouteService = JourneyRouteService()
    private let tripPlanner = ChargingTripPlanner()
    private var pendingStationKey: String?
    private var prepared = false

    var userLocation: UserLocation?
    var state: SearchState = .idle
    private(set) var journeySnapshot: JourneyRouteSnapshot?
    private(set) var tripPlan: ChargingTripPlan?

    init(
        stationData: StationDataStore,
        settings: UserSettingsStore,
        favorites: FavoritesStore,
        auth: AuthStore,
        navigation: NavigationCoordinator,
        messages: AppMessagePresenter,
        demandAnalytics: any DemandAnalyticsClient = UnavailableDemandAnalyticsClient()
    ) {
        self.stationData = stationData
        self.settings = settings
        self.favorites = favorites
        self.auth = auth
        self.navigation = navigation
        self.messages = messages
        self.demandAnalytics = demandAnalytics
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
        journeySnapshot = nil
        tripPlan = nil
        if let pendingStationKey {
            self.pendingStationKey = nil
            Task { await openStation(withKey: pendingStationKey) }
        }
    }

    func reset() {
        state = .idle
        journeySnapshot = nil
        tripPlan = nil
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
                let snapshot = try await journeyRouteService.routeSnapshot(
                    origin: userLocation,
                    destination: destination
                )
                journeySnapshot = snapshot
                routePoints = snapshot.points
            } catch {
                journeySnapshot = nil
                routePoints = []
                AppLogger.routing.warning("Journey corridor route failed: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            journeySnapshot = nil
            routePoints = []
        }

        var searchFilters = settings.filters
        if settings.destination != nil {
            searchFilters.rangeFilterEnabled = false
        }
        let planningCandidates = await stationData.candidates(
            origin: userLocation,
            destination: settings.destination,
            routePoints: routePoints,
            profile: settings.profile,
            filters: searchFilters,
            limit: settings.destination == nil ? 80 : 240
        )
        if let snapshot = journeySnapshot {
            tripPlan = tripPlanner.plan(
                routeDistanceKm: snapshot.distanceKm,
                candidates: planningCandidates,
                profile: settings.profile,
                estimatedDrivingMinutes: snapshot.estimatedMinutes,
                elevation: snapshot.elevation
            )
        } else {
            tripPlan = nil
        }
        let result = Array(planningCandidates.prefix(80))
        if let nearestFast = result
            .filter({ $0.station.powerKW >= 50 })
            .min(by: { $0.distanceKm < $1.distanceKm }) {
            WidgetSnapshotStore.save(WidgetSnapshot(
                stationName: nearestFast.station.name,
                distanceKm: nearestFast.distanceKm,
                power: nearestFast.station.power,
                safeRangeKm: Int(profileSafeRange.rounded()),
                updatedAt: Date(),
                languageCode: settings.language.rawValue
            ))
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            state = .results(result)
            navigation.select(.routes)
        }
        await recordDemandIfEnabled(origin: userLocation, resultCount: result.count)
    }

    private var profileSafeRange: Double { settings.profile.safeRangeKm }

    private func recordDemandIfEnabled(origin: UserLocation, resultCount: Int) async {
        guard settings.demandAnalyticsEnabled, auth.isAuthenticated else { return }
        let event = SearchDemandEvent(
            location: origin,
            preference: settings.filters.preference,
            searchRadiusKm: settings.filters.rangeFilterEnabled ? settings.profile.safeRangeKm : 400,
            resultCount: resultCount
        )
        do {
            try await auth.authenticatedRequest { session in
                try await self.demandAnalytics.recordSearchDemand(
                    event: event,
                    uid: session.uid,
                    idToken: session.idToken
                )
            }
        } catch {
            AppLogger.data.debug("Opt-in demand event skipped: \(error.localizedDescription, privacy: .public)")
        }
    }

    func openNearestFast() async {
        settings.filters.preference = .fastest
        navigation.select(.home)
        if userLocation != nil { await findStations() }
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
