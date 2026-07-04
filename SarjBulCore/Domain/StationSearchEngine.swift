import Foundation

public struct StationSearchEngine: Sendable {
    public init() {}

    public func candidates(
        from stations: [Station],
        origin: UserLocation,
        profile: DrivingProfile,
        filters: StationFilters,
        limit: Int = 80
    ) -> [StationCandidate] {
        let normalizedSearch = filters.searchText.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "tr_TR")
        )

        var candidates: [StationCandidate] = []
        candidates.reserveCapacity(min(stations.count, limit))

        for station in stations {
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

            var candidate = StationCandidate(
                station: station,
                distanceKm: (distance * 10).rounded() / 10,
                straightLineDistanceKm: (straightLine * 10).rounded() / 10,
                estimatedMinutes: DistanceCalculator.estimatedMinutes(distanceKm: distance),
                arrivalChargePercent: profile.arrivalChargePercent(distanceKm: distance),
                remainingSafeRangeKm: max(0, profile.safeRangeKm - distance),
                score: 1,
                badges: []
            )
            candidate.score = StationScorer.score(candidate: candidate)
            candidate.badges = StationScorer.badges(for: candidate)
            candidates.append(candidate)
        }

        return candidates.sorted(preference: filters.preference).prefix(limit).map { $0 }
    }
}

private extension Array where Element == StationCandidate {
    func sorted(preference: RoutePreference) -> [StationCandidate] {
        switch preference {
        case .balanced:
            sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.distanceKm < rhs.distanceKm
            }
        case .nearest:
            sorted { lhs, rhs in
                if lhs.distanceKm != rhs.distanceKm { return lhs.distanceKm < rhs.distanceKm }
                return lhs.score > rhs.score
            }
        case .fastest:
            sorted { lhs, rhs in
                if lhs.station.powerKW != rhs.station.powerKW { return lhs.station.powerKW > rhs.station.powerKW }
                return lhs.distanceKm < rhs.distanceKm
            }
        case .economical:
            sorted { lhs, rhs in
                if lhs.station.priceValue != rhs.station.priceValue { return lhs.station.priceValue < rhs.station.priceValue }
                return lhs.distanceKm < rhs.distanceKm
            }
        }
    }
}
