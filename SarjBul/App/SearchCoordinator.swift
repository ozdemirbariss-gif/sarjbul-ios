import Observation
import MapKit
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
    private enum PendingQuickAction {
        case nearestFast
    }

    private let stationData: StationDataStore
    private let settings: UserSettingsStore
    private let favorites: FavoritesStore
    private let auth: AuthStore
    private let navigation: NavigationCoordinator
    private let messages: AppMessagePresenter
    private let habits: HabitStore
    private let offlineSync: OfflineSyncCoordinator
    private let executionTrust: ExecutionTrustStore
    private let frictionTelemetry: FrictionTelemetryStore
    private let journeyRouteService = JourneyRouteService()
    private let tripPlanner = ChargingTripPlanner()
    private var pendingStationKey: String?
    private var pendingQuickAction: PendingQuickAction?
    private var prepared = false
    private var isPreparingOutcome = false

    var userLocation: SarjBulCore.UserLocation?
    var state: SearchState = .idle
    private(set) var journeySnapshot: JourneyRouteSnapshot?
    private(set) var tripPlan: ChargingTripPlan?
    private(set) var locationNeedsReview = false
    private(set) var previousCandidates: [StationCandidate] = []

    init(
        stationData: StationDataStore,
        settings: UserSettingsStore,
        favorites: FavoritesStore,
        auth: AuthStore,
        navigation: NavigationCoordinator,
        messages: AppMessagePresenter,
        habits: HabitStore,
        offlineSync: OfflineSyncCoordinator,
        executionTrust: ExecutionTrustStore,
        frictionTelemetry: FrictionTelemetryStore
    ) {
        self.stationData = stationData
        self.settings = settings
        self.favorites = favorites
        self.auth = auth
        self.navigation = navigation
        self.messages = messages
        self.habits = habits
        self.offlineSync = offlineSync
        self.executionTrust = executionTrust
        self.frictionTelemetry = frictionTelemetry
    }

    var routeCandidates: [StationCandidate] { state.candidates }
    var preparedCandidate: StationCandidate? { routeCandidates.first ?? previousCandidates.first }
    var isSearching: Bool { state.isSearching }
    var canSearch: Bool { userLocation != nil && !isSearching }

    func prepare() async {
        guard !prepared else { return }
        prepared = true
        await auth.prepare()
        let session = try? await auth.validSession()
        await stationData.load(statusIDToken: session?.idToken)
        stationData.startRealtime(idToken: session?.idToken)
        if auth.isConfigured { await favorites.load() }
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

    func updateLocation(latitude: Double, longitude: Double, source: SarjBulCore.UserLocation.Source) {
        userLocation = SarjBulCore.UserLocation(latitude: latitude, longitude: longitude, source: source)
        locationNeedsReview = false
        state = .idle
        journeySnapshot = nil
        tripPlan = nil
        if let pendingStationKey {
            self.pendingStationKey = nil
            Task { await openStation(withKey: pendingStationKey) }
        } else if pendingQuickAction == .nearestFast {
            pendingQuickAction = nil
            Task { await findStations() }
        }
    }

    func reset() {
        state = .idle
        journeySnapshot = nil
        tripPlan = nil
        locationNeedsReview = false
    }

    func applyFilters(_ filters: StationFilters) async {
        settings.filters = filters
        guard userLocation != nil else { return }
        await findStations()
    }

    func prepareOutcome() async {
        guard !isPreparingOutcome, userLocation != nil else { return }
        isPreparingOutcome = true
        defer { isPreparingOutcome = false }
        await findStations(presentResults: false)
    }

    func findStations(presentResults: Bool = true) async {
        let startedAt = Date()
        guard let userLocation else {
            state = .failed(.localized(key: "route.location_required", kind: .error))
            recordSearchProof(
                status: .failed,
                resultKey: "missing-location",
                candidates: [],
                location: nil,
                startedAt: startedAt
            )
            return
        }
        guard !isSearching else { return }

        locationNeedsReview = false
        frictionTelemetry.record(.stationSearchStarted)
        if presentResults {
            previousCandidates = routeCandidates
            state = .searching
        }
        guard await ensureDataset(
            presentResults: presentResults,
            location: userLocation,
            startedAt: startedAt
        ) else { return }

        let routePoints = await prepareRoutePoints(origin: userLocation)
        var searchFilters = settings.filters
        if settings.destination != nil {
            searchFilters.rangeFilterEnabled = false
        }
        let rawCandidates = await searchCandidates(
            origin: userLocation,
            routePoints: routePoints,
            filters: searchFilters
        )

        guard !rawCandidates.isEmpty else {
            await handleNoCandidates(
                presentResults: presentResults,
                location: userLocation,
                startedAt: startedAt
            )
            return
        }

        await completeSearch(
            rawCandidates,
            presentResults: presentResults,
            location: userLocation,
            startedAt: startedAt
        )
    }

    private func ensureDataset(
        presentResults: Bool,
        location: SarjBulCore.UserLocation,
        startedAt: Date
    ) async -> Bool {
        if stationData.stations.isEmpty {
            let session = try? await auth.validSession()
            await stationData.retry(statusIDToken: session?.idToken)
        }
        guard stationData.stations.isEmpty else { return true }
        if presentResults, previousCandidates.isEmpty {
            state = .failed(.localized(key: "data.recovery_failed", kind: .error))
            navigation.select(.routes)
        }
        frictionTelemetry.record(.noOutcome)
        recordSearchProof(
            status: .failed,
            resultKey: "missing-dataset",
            candidates: [],
            location: location,
            startedAt: startedAt
        )
        return false
    }

    private func searchCandidates(
        origin: SarjBulCore.UserLocation,
        routePoints: [SarjBulCore.UserLocation],
        filters: StationFilters
    ) async -> [StationCandidate] {
        let limit = settings.destination == nil ? 24 : 120
        var candidates = await stationData.candidates(
            origin: origin,
            destination: settings.destination,
            routePoints: routePoints,
            profile: settings.profile,
            filters: filters,
            limit: limit
        )
        let recoveryFilters = relaxedFilters(from: filters)
        if candidates.isEmpty, recoveryFilters != filters {
            candidates = await stationData.candidates(
                origin: origin,
                destination: settings.destination,
                routePoints: routePoints,
                profile: settings.profile,
                filters: recoveryFilters,
                limit: limit
            )
            if !candidates.isEmpty {
                AppLogger.routing.notice("Station search recovered with safe fallback filters")
            }
        }
        return candidates
    }

    private func handleNoCandidates(
        presentResults: Bool,
        location: SarjBulCore.UserLocation,
        startedAt: Date
    ) async {
        if settings.destination == nil {
            locationNeedsReview = true
            if previousCandidates.isEmpty { state = .idle }
            if presentResults { navigation.select(.home) }
            AppLogger.routing.warning("Station search found no nearby candidates after fallback")
        } else {
            if presentResults {
                state = .results([])
                navigation.select(.routes)
            }
            AppLogger.routing.warning("Journey search found no corridor candidates after fallback")
        }
        await recordDemandIfEnabled(origin: location, resultCount: 0)
        frictionTelemetry.record(.noOutcome)
        recordSearchProof(
            status: .failed,
            resultKey: "no-candidate",
            candidates: [],
            location: location,
            startedAt: startedAt
        )
    }

    private func completeSearch(
        _ rawCandidates: [StationCandidate],
        presentResults: Bool,
        location: SarjBulCore.UserLocation,
        startedAt: Date
    ) async {
        let planningCandidates = habits.personalize(rawCandidates)
        updateTripPlan(with: planningCandidates)
        let result = Array(planningCandidates.prefix(24))
        saveWidgetSnapshot(from: result)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            state = .results(result)
            if presentResults { navigation.select(.routes) }
        }
        previousCandidates = result
        frictionTelemetry.record(.outcomeReady)
        habits.recordSearch(filters: settings.filters)
        recordSearchProof(
            status: .completed,
            resultKey: result[0].station.statusKey,
            candidates: result,
            location: location,
            startedAt: startedAt
        )
        await recordDemandIfEnabled(origin: location, resultCount: result.count)
    }

    private func updateTripPlan(with candidates: [StationCandidate]) {
        guard let snapshot = journeySnapshot else {
            tripPlan = nil
            return
        }
        tripPlan = tripPlanner.plan(
            routeDistanceKm: snapshot.distanceKm,
            candidates: candidates,
            profile: settings.profile,
            estimatedDrivingMinutes: snapshot.estimatedMinutes,
            elevation: snapshot.elevation
        )
    }

    private func saveWidgetSnapshot(from candidates: [StationCandidate]) {
        guard let nearestFast = candidates
            .filter({ $0.station.powerKW >= 50 })
            .min(by: { $0.distanceKm < $1.distanceKm }) else { return }
        WidgetSnapshotStore.save(WidgetSnapshot(
            stationName: nearestFast.station.name,
            distanceKm: nearestFast.distanceKm,
            power: nearestFast.station.power,
            safeRangeKm: Int(profileSafeRange.rounded()),
            updatedAt: Date(),
            languageCode: settings.language.rawValue
        ))
    }

    func presentPreparedResults() {
        guard !routeCandidates.isEmpty || !previousCandidates.isEmpty else { return }
        if routeCandidates.isEmpty { state = .results(previousCandidates) }
        navigation.select(.routes)
    }

    func startNavigation(to candidate: StationCandidate) {
        guard let preference = settings.navigationAppPreference else { return }
        startNavigation(to: candidate, using: preference)
    }

    func startNavigation(to candidate: StationCandidate, using preference: NavigationAppPreference) {
        settings.navigationAppPreference = preference
        favorites.recordRouteOpened(candidate.station)
        habits.recordRouteOpened(candidate)
        frictionTelemetry.record(.routeStarted)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-navigation-picker") { return }
        #endif
        switch preference {
        case .appleMaps:
            openInAppleMaps(candidate)
        case .googleMaps:
            openInGoogleMaps(candidate)
        }
    }

    private func openInAppleMaps(_ candidate: StationCandidate) {
        let coordinate = CLLocationCoordinate2D(
            latitude: candidate.station.latitude,
            longitude: candidate.station.longitude
        )
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        destination.name = candidate.station.name
        destination.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func openInGoogleMaps(_ candidate: StationCandidate) {
        var components = URLComponents(string: "https://www.google.com/maps/dir/")
        components?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(
                name: "destination",
                value: "\(candidate.station.latitude),\(candidate.station.longitude)"
            ),
            URLQueryItem(name: "travelmode", value: "driving"),
            URLQueryItem(name: "dir_action", value: "navigate")
        ]
        guard let url = components?.url else { return }
        UIApplication.shared.open(url)
    }

    private func relaxedFilters(from filters: StationFilters) -> StationFilters {
        var relaxed = filters
        relaxed.searchText = ""
        relaxed.minimumPowerKW = 0
        relaxed.socketFilters = []
        relaxed.operatorFilters = []
        relaxed.rangeFilterEnabled = false
        return relaxed
    }

    private func prepareRoutePoints(origin: SarjBulCore.UserLocation) async -> [SarjBulCore.UserLocation] {
        guard let destination = settings.destination else {
            journeySnapshot = nil
            return []
        }
        do {
            let snapshot = try await journeyRouteService.routeSnapshot(
                origin: origin,
                destination: destination
            )
            journeySnapshot = snapshot
            return snapshot.points
        } catch {
            journeySnapshot = nil
            AppTelemetry.capture(error, operation: "journey_route_fallback")
            AppLogger.routing.warning(
                "Journey corridor route failed: \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }

    func applyRealtime(_ event: StationRealtimeEvent) {
        guard case .results(var candidates) = state else { return }
        for index in candidates.indices {
            let key = candidates[index].station.statusKey
            let id = candidates[index].station.id
            switch event {
            case .statusesSnapshot(let values):
                candidates[index].status = values[key] ?? values[id]
            case .statusChanged(let changedKey, let value) where changedKey == key || changedKey == id:
                candidates[index].status = value
            case .insightsSnapshot(let values):
                candidates[index].communityInsight = values[key] ?? values[id]
            case .insightChanged(let changedKey, let value) where changedKey == key || changedKey == id:
                candidates[index].communityInsight = value
            case .availabilitySnapshot(let values):
                candidates[index].liveAvailability = values[key] ?? values[id]
            case .availabilityChanged(let changedKey, let value) where changedKey == key || changedKey == id:
                candidates[index].liveAvailability = value
            default:
                continue
            }
            candidates[index].score = StationScorer.score(candidate: candidates[index])
            candidates[index].badges = StationScorer.badges(for: candidates[index])
        }
        state = .results(candidates)
    }

    private var profileSafeRange: Double { settings.profile.safeRangeKm }

    private func recordDemandIfEnabled(origin: SarjBulCore.UserLocation, resultCount: Int) async {
        guard settings.demandAnalyticsEnabled else { return }
        let event = SearchDemandEvent(
            location: origin,
            preference: settings.filters.preference,
            searchRadiusKm: settings.filters.rangeFilterEnabled ? settings.profile.safeRangeKm : 400,
            resultCount: resultCount
        )
        await offlineSync.submit(
            .demand(event),
            deduplicationKey: "demand:\(event.coarseCell):\(event.createdAtMilliseconds)"
        ) { _ in }
    }

    func openNearestFast() async {
        settings.filters.preference = .fastest
        navigation.select(.home)
        guard userLocation != nil else {
            pendingQuickAction = .nearestFast
            return
        }
        pendingQuickAction = nil
        await findStations()
    }

    func openStation(withKey key: String) async {
        let startedAt = Date()
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
        let selected = candidates.first(where: { $0.station.statusKey == key || $0.station.id == station.id })
        executionTrust.record(
            action: .routeOpened,
            intentKey: "open-route",
            resultKey: key,
            status: .completed,
            evidence: evidence(for: selected, location: origin) + [ExecutionEvidence(
                source: .userAction,
                reliability: 1,
                observedAt: Date(),
                maximumAge: 60
            )],
            deterministicChecks: [
                "station-resolved": selected != nil,
                "origin-available": true,
                "route-visible": navigation.tab == .routes
            ],
            contextKeys: executionTrust.contextKeys(
                location: origin,
                preference: settings.filters.preference
            ),
            startedAt: startedAt,
            estimatedTimeSavedSeconds: 120
        )
    }

    private func recordSearchProof(
        status: ExecutionProofStatus,
        resultKey: String,
        candidates: [StationCandidate],
        location: SarjBulCore.UserLocation?,
        startedAt: Date
    ) {
        executionTrust.record(
            action: .stationSearch,
            intentKey: "search:\(settings.filters.preference.rawValue)",
            resultKey: resultKey,
            status: status,
            evidence: evidence(for: candidates.first, location: location),
            deterministicChecks: [
                "location-valid": location.map {
                    (-90...90).contains($0.latitude) && (-180...180).contains($0.longitude)
                } ?? false,
                "candidate-found": !candidates.isEmpty,
                "candidate-safe": candidates.first.map { !$0.hasRiskyStatus } ?? false
            ],
            contextKeys: executionTrust.contextKeys(
                location: location,
                preference: settings.filters.preference
            ),
            startedAt: startedAt,
            estimatedTimeSavedSeconds: status == .completed ? 90 : 0
        )
    }

    private func evidence(
        for candidate: StationCandidate?,
        location: SarjBulCore.UserLocation?
    ) -> [ExecutionEvidence] {
        let now = Date()
        var result = [ExecutionEvidence(
            source: .deterministicEngine,
            reliability: 1,
            observedAt: now,
            maximumAge: 60
        )]
        if let location {
            result.append(ExecutionEvidence(
                source: location.source == .device ? .deviceLocation : .manualLocation,
                reliability: location.source == .device ? 0.98 : 0.90,
                observedAt: now,
                maximumAge: location.source == .device ? 300 : 86_400
            ))
        }
        if let candidate {
            result.append(ExecutionEvidence(
                source: .stationDataset,
                reliability: candidate.station.confidenceScore,
                observedAt: executionTrust.stationObservedAt(candidate.station, fallback: now),
                maximumAge: 30 * 86_400
            ))
            if let availability = candidate.liveAvailability {
                result.append(ExecutionEvidence(
                    source: .realtimeAvailability,
                    reliability: 0.98,
                    observedAt: availability.updatedAt,
                    maximumAge: 15 * 60
                ))
            }
        }
        return result
    }
}
