import Foundation

public actor StationDataPipeline {
    private let repository: any StationRepository
    private let statusClient: any StatusClient
    private let searchEngine: StationSearchEngine
    private var stations: [Station] = []
    private var statuses: [String: StationStatusSummary] = [:]
    private var spatialIndex = SpatialIndex(stations: [])

    public init(
        repository: any StationRepository,
        statusClient: any StatusClient,
        searchEngine: StationSearchEngine = StationSearchEngine()
    ) {
        self.repository = repository
        self.statusClient = statusClient
        self.searchEngine = searchEngine
    }

    public func loadStations() async throws -> [Station] {
        if stations.isEmpty {
            replaceStations(try await repository.loadStations())
        }
        return stations
    }

    public func refreshStations() async throws -> [Station]? {
        guard let refreshable = repository as? any RefreshableStationRepository,
              let refreshed = try await refreshable.refreshStations(),
              !refreshed.isEmpty else { return nil }
        replaceStations(refreshed)
        return refreshed
    }

    public func reloadStatuses(idToken: String? = nil) async throws -> [String: StationStatusSummary] {
        statuses = try await statusClient.stationStatuses(idToken: idToken)
        return statuses
    }

    public func snapshot() -> (stations: [Station], statuses: [String: StationStatusSummary]) {
        (stations, statuses)
    }

    public func station(withKey key: String) -> Station? {
        stations.first { $0.statusKey == key || $0.id == key }
    }

    public func search(
        origin: UserLocation,
        destination: JourneyDestination?,
        routePoints: [UserLocation],
        profile: DrivingProfile,
        filters: StationFilters,
        limit: Int = 80
    ) -> [StationCandidate] {
        if let destination {
            let destinationLocation = UserLocation(
                latitude: destination.latitude,
                longitude: destination.longitude,
                source: .manual
            )
            let points = [origin] + routePoints + [destinationLocation]
            let candidates = spatialIndex.stations(along: points, paddingKm: 30)
            return searchEngine.candidatesAlongJourney(
                from: candidates,
                origin: origin,
                destination: destination,
                routePoints: routePoints,
                profile: profile,
                filters: filters,
                stationStatuses: statuses,
                limit: limit
            )
        }

        return searchEngine.candidates(
            in: spatialIndex,
            origin: origin,
            profile: profile,
            filters: filters,
            stationStatuses: statuses,
            limit: limit
        )
    }

    public func directCandidate(
        station: Station,
        origin: UserLocation,
        profile: DrivingProfile,
        filters: StationFilters
    ) -> StationCandidate? {
        searchEngine.candidates(
            from: [station],
            origin: origin,
            profile: profile,
            filters: filters,
            stationStatuses: statuses,
            limit: 1
        ).first
    }

    private func replaceStations(_ newStations: [Station]) {
        stations = newStations
        spatialIndex = SpatialIndex(stations: newStations)
    }
}
