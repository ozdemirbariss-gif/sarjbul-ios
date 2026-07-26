import Foundation

public actor StationDataPipeline {
    private let repository: any StationRepository
    private let statusClient: any StatusClient
    private let liveAvailabilityClient: any LiveAvailabilityClient
    private let searchEngine: StationSearchEngine
    private var stations: [Station] = []
    private var statuses: [String: StationStatusSummary] = [:]
    private var insights: [String: StationCommunityInsight] = [:]
    private var liveAvailability: [String: LiveStationAvailability] = [:]
    private var spatialIndex = SpatialIndex(stations: [])

    public init(
        repository: any StationRepository,
        statusClient: any StatusClient,
        liveAvailabilityClient: any LiveAvailabilityClient = UnavailableLiveAvailabilityClient(),
        searchEngine: StationSearchEngine = StationSearchEngine()
    ) {
        self.repository = repository
        self.statusClient = statusClient
        self.liveAvailabilityClient = liveAvailabilityClient
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

    public func reloadCommunityInsights(idToken: String? = nil) async throws -> [String: StationCommunityInsight] {
        insights = try await statusClient.stationCommunityInsights(idToken: idToken)
        return insights
    }

    public func snapshot() -> (
        stations: [Station],
        statuses: [String: StationStatusSummary],
        insights: [String: StationCommunityInsight]
    ) {
        (stations, statuses, insights)
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
    ) async -> [StationCandidate] {
        let result: [StationCandidate]
        if let destination {
            let destinationLocation = UserLocation(
                latitude: destination.latitude,
                longitude: destination.longitude,
                source: .manual
            )
            let points = [origin] + routePoints + [destinationLocation]
            let candidates = spatialIndex.stations(along: points, paddingKm: 30)
            result = searchEngine.candidatesAlongJourney(
                from: candidates,
                origin: origin,
                destination: destination,
                routePoints: routePoints,
                profile: profile,
                filters: filters,
                stationStatuses: statuses,
                limit: limit
            )
        } else {
            result = searchEngine.candidates(
                in: spatialIndex,
                origin: origin,
                profile: profile,
                filters: filters,
                stationStatuses: statuses,
                limit: limit
            )
        }
        return await enrich(result)
    }

    public func directCandidate(
        station: Station,
        origin: UserLocation,
        profile: DrivingProfile,
        filters: StationFilters
    ) async -> StationCandidate? {
        let result = searchEngine.candidates(
            from: [station],
            origin: origin,
            profile: profile,
            filters: filters,
            stationStatuses: statuses,
            limit: 1
        )
        return await enrich(result).first
    }

    private func replaceStations(_ newStations: [Station]) {
        stations = newStations
        spatialIndex = SpatialIndex(stations: newStations)
    }

    private func enrich(_ candidates: [StationCandidate]) async -> [StationCandidate] {
        let keys = candidates.map { $0.station.statusKey }
        if let fresh = try? await liveAvailabilityClient.availability(stationKeys: keys) {
            liveAvailability.merge(fresh) { _, new in new }
        }

        return candidates.map { original in
            var candidate = original
            let key = candidate.station.statusKey
            candidate.communityInsight = insights[key] ?? insights[candidate.station.id]
            candidate.liveAvailability = liveAvailability[key] ?? liveAvailability[candidate.station.id]
            candidate.station.confidenceScore = StationDataQuality.confidence(
                station: candidate.station,
                insight: candidate.communityInsight
            )
            return candidate
        }
    }
}
