import Foundation

public struct StationSearchEngine: Sendable {
    private let rawCandidateLimit = 240
    private let richCandidateLimit = 80
    private let defaultCandidateRadiusKm = 80.0
    private let maxCandidateRadiusKm = 900.0

    public init() {}

    public func candidates(
        from stations: [Station],
        origin: UserLocation,
        profile: DrivingProfile,
        filters: StationFilters,
        stationStatuses: [String: StationStatusSummary] = [:],
        limit: Int = 80
    ) -> [StationCandidate] {
        let normalizedSearch = filters.searchText.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "tr_TR")
        )

        var candidates: [StationCandidate] = []
        candidates.reserveCapacity(min(stations.count, rawCandidateLimit))

        for radiusKm in radiusSteps(rangeFilterEnabled: filters.rangeFilterEnabled, safeRangeKm: profile.safeRangeKm) {
            candidates.removeAll(keepingCapacity: true)

            for station in stations {
                guard isInsideBoundingBox(station: station, origin: origin, radiusKm: radiusKm) else { continue }
                guard station.powerKW >= filters.minimumPowerKW else { continue }
                guard filters.socketFilters.isEmpty || filters.socketFilters.contains(where: { station.socket.localizedCaseInsensitiveContains($0) }) else { continue }
                guard filters.operatorFilters.isEmpty || filters.operatorFilters.contains(station.operatorName) else { continue }
                guard normalizedSearch.isEmpty || station.searchKey.contains(normalizedSearch) else { continue }

                let straightLine = DistanceCalculator.haversineKm(
                    from: origin,
                    toLatitude: station.latitude,
                    longitude: station.longitude
                )
                let distance = DistanceCalculator.estimatedRoadDistanceKm(straightLineKm: straightLine)
                guard !filters.rangeFilterEnabled || distance <= profile.safeRangeKm else { continue }

                candidates.append(StationCandidate(
                    station: station,
                    status: stationStatuses[station.statusKey] ?? stationStatuses[station.id],
                    distanceKm: (distance * 10).rounded() / 10,
                    straightLineDistanceKm: (straightLine * 10).rounded() / 10,
                    estimatedMinutes: DistanceCalculator.estimatedMinutes(distanceKm: distance),
                    arrivalChargePercent: profile.arrivalChargePercent(distanceKm: distance),
                    remainingSafeRangeKm: max(0, profile.safeRangeKm - distance),
                    score: 1,
                    badges: []
                ))
            }

            if candidates.count >= richCandidateLimit || radiusKm >= maxCandidateRadiusKm {
                break
            }
        }

        let rawCandidates = Array(candidates.roughSorted(preference: filters.preference).prefix(rawCandidateLimit))
        let richCandidates = rawCandidates.prefix(richCandidateLimit).map { candidate in
            var candidate = candidate
            candidate.score = StationScorer.score(candidate: candidate)
            candidate.badges = StationScorer.badges(for: candidate)
            return candidate
        }

        return richCandidates.sorted(preference: filters.preference).prefix(limit).map { $0 }
    }

    private func radiusSteps(rangeFilterEnabled: Bool, safeRangeKm: Double) -> [Double] {
        var radius = max(20, rangeFilterEnabled ? safeRangeKm : defaultCandidateRadiusKm)
        var steps: [Double] = []

        while radius <= maxCandidateRadiusKm {
            let rounded = (radius * 10).rounded() / 10
            if !steps.contains(rounded) {
                steps.append(rounded)
            }
            radius *= 2
        }

        if steps.last != maxCandidateRadiusKm {
            steps.append(maxCandidateRadiusKm)
        }

        return steps
    }

    private func isInsideBoundingBox(station: Station, origin: UserLocation, radiusKm: Double) -> Bool {
        let latitudeDelta = radiusKm / 111.0
        let cosineLatitude = max(0.18, abs(cos(origin.latitude * .pi / 180)))
        let longitudeDelta = radiusKm / (111.0 * cosineLatitude)
        return abs(station.latitude - origin.latitude) <= latitudeDelta
            && abs(station.longitude - origin.longitude) <= longitudeDelta
    }
}

private extension Array where Element == StationCandidate {
    func roughSorted(preference: RoutePreference) -> [StationCandidate] {
        switch preference {
        case .balanced:
            sorted {
                if $0.distanceKm != $1.distanceKm { return $0.distanceKm < $1.distanceKm }
                if $0.station.powerKW != $1.station.powerKW { return $0.station.powerKW > $1.station.powerKW }
                return $0.station.priceValue < $1.station.priceValue
            }
        case .nearest:
            sorted { $0.distanceKm < $1.distanceKm }
        case .fastest:
            sorted {
                if $0.station.powerKW != $1.station.powerKW { return $0.station.powerKW > $1.station.powerKW }
                return $0.distanceKm < $1.distanceKm
            }
        case .economical:
            sorted {
                if $0.station.priceValue != $1.station.priceValue { return $0.station.priceValue < $1.station.priceValue }
                return $0.distanceKm < $1.distanceKm
            }
        }
    }

    func sorted(preference: RoutePreference) -> [StationCandidate] {
        switch preference {
        case .balanced:
            sorted { lhs, rhs in
                if lhs.hasRiskyStatus != rhs.hasRiskyStatus { return !lhs.hasRiskyStatus }
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.distanceKm < rhs.distanceKm
            }
        case .nearest:
            sorted { lhs, rhs in
                if lhs.hasRiskyStatus != rhs.hasRiskyStatus { return !lhs.hasRiskyStatus }
                if lhs.distanceKm != rhs.distanceKm { return lhs.distanceKm < rhs.distanceKm }
                return lhs.score > rhs.score
            }
        case .fastest:
            sorted { lhs, rhs in
                if lhs.hasRiskyStatus != rhs.hasRiskyStatus { return !lhs.hasRiskyStatus }
                if lhs.station.powerKW != rhs.station.powerKW { return lhs.station.powerKW > rhs.station.powerKW }
                return lhs.distanceKm < rhs.distanceKm
            }
        case .economical:
            sorted { lhs, rhs in
                if lhs.hasRiskyStatus != rhs.hasRiskyStatus { return !lhs.hasRiskyStatus }
                if lhs.station.priceValue != rhs.station.priceValue { return lhs.station.priceValue < rhs.station.priceValue }
                return lhs.distanceKm < rhs.distanceKm
            }
        }
    }
}
