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
    private var availabilityTask: Task<Void, Never>?
    private var pendingAvailabilityKeys: Set<String> = []
    private var availabilityAttemptedAt: [String: Date] = [:]
    private var availabilityObservers: [UUID: AsyncStream<StationRealtimeEvent>.Continuation] = [:]

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

    public func seedCommunitySnapshots(
        statuses: [String: StationStatusSummary],
        insights: [String: StationCommunityInsight]
    ) {
        if self.statuses.isEmpty { self.statuses = statuses }
        if self.insights.isEmpty { self.insights = insights }
    }

    public func station(withKey key: String) -> Station? {
        stations.first { $0.statusKey == key || $0.id == key }
    }

    public func applyRealtime(_ event: StationRealtimeEvent) {
        switch event {
        case .statusesSnapshot(let values):
            statuses = values
        case .statusChanged(let key, let value):
            statuses[key] = value
        case .insightsSnapshot(let values):
            insights = values
        case .insightChanged(let key, let value):
            insights[key] = value
        case .availabilitySnapshot(let values):
            liveAvailability = values
        case .availabilityChanged(let key, let value):
            liveAvailability[key] = value
        }
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
        scheduleAvailabilityRefresh(for: result)
        return enrich(result)
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
        scheduleAvailabilityRefresh(for: result)
        return enrich(result).first
    }

    private func replaceStations(_ newStations: [Station]) {
        stations = newStations
        spatialIndex = SpatialIndex(stations: newStations)
    }

    private func enrich(_ candidates: [StationCandidate]) -> [StationCandidate] {
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

    public func availabilityUpdates() -> AsyncStream<StationRealtimeEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<StationRealtimeEvent>.makeStream(bufferingPolicy: .bufferingNewest(1))
        availabilityObservers[id] = continuation
        continuation.yield(.availabilitySnapshot(liveAvailability))
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeAvailabilityObserver(id) }
        }
        return stream
    }

    private func removeAvailabilityObserver(_ id: UUID) {
        availabilityObservers[id] = nil
    }

    private func scheduleAvailabilityRefresh(for candidates: [StationCandidate]) {
        let now = Date()
        availabilityAttemptedAt = availabilityAttemptedAt.filter { now.timeIntervalSince($0.value) < 60 }
        pendingAvailabilityKeys = Set(candidates.map { $0.station.statusKey }.filter {
            availabilityAttemptedAt[$0] == nil
        })
        guard availabilityTask == nil, !pendingAvailabilityKeys.isEmpty else { return }
        availabilityTask = Task { [weak self] in await self?.drainAvailabilityRefresh() }
    }

    private func drainAvailabilityRefresh() async {
        defer { availabilityTask = nil }
        while !pendingAvailabilityKeys.isEmpty {
            let keys = pendingAvailabilityKeys
            pendingAvailabilityKeys.removeAll()
            for key in keys { availabilityAttemptedAt[key] = Date() }
            guard let values = try? await liveAvailabilityClient.availability(stationKeys: Array(keys)) else { continue }
            let now = Date()
            for (key, value) in values where keys.contains(key)
                && now.timeIntervalSince(value.updatedAt) >= -5
                && now.timeIntervalSince(value.updatedAt) <= 15 * 60 {
                if let current = liveAvailability[key], current.updatedAt > value.updatedAt { continue }
                liveAvailability[key] = value
            }
            for observer in availabilityObservers.values {
                observer.yield(.availabilitySnapshot(liveAvailability))
            }
        }
    }
}
