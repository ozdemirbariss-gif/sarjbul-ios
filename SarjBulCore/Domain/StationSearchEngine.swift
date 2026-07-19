import Foundation

public struct StationSearchEngine: Sendable {
    private let rawCandidateLimit = 240
    private let richCandidateLimit = 80
    private let defaultCandidateRadiusKm = 80.0
    private let maxCandidateRadiusKm = 900.0

    public init() {}

    public func candidates(
        in index: SpatialIndex,
        origin: UserLocation,
        profile: DrivingProfile,
        filters: StationFilters,
        stationStatuses: [String: StationStatusSummary] = [:],
        limit: Int = 80
    ) -> [StationCandidate] {
        var latestResult: [StationCandidate] = []
        for radiusKm in radiusSteps(rangeFilterEnabled: filters.rangeFilterEnabled, safeRangeKm: profile.safeRangeKm) {
            let result = candidates(
                from: index.stations(near: origin, radiusKm: radiusKm),
                origin: origin,
                profile: profile,
                filters: filters,
                stationStatuses: stationStatuses,
                limit: limit,
                radiusSteps: [radiusKm]
            )
            latestResult = result
            if result.count >= richCandidateLimit || radiusKm >= maxCandidateRadiusKm {
                return result
            }
        }
        return latestResult
    }

    public func candidates(
        from stations: [Station],
        origin: UserLocation,
        profile: DrivingProfile,
        filters: StationFilters,
        stationStatuses: [String: StationStatusSummary] = [:],
        limit: Int = 80
    ) -> [StationCandidate] {
        candidates(
            from: stations,
            origin: origin,
            profile: profile,
            filters: filters,
            stationStatuses: stationStatuses,
            limit: limit,
            radiusSteps: radiusSteps(rangeFilterEnabled: filters.rangeFilterEnabled, safeRangeKm: profile.safeRangeKm)
        )
    }

    private func candidates(
        from stations: [Station],
        origin: UserLocation,
        profile: DrivingProfile,
        filters: StationFilters,
        stationStatuses: [String: StationStatusSummary],
        limit: Int,
        radiusSteps: [Double]
    ) -> [StationCandidate] {
        let normalizedSearch = filters.searchText.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "tr_TR")
        )

        var candidates: [StationCandidate] = []
        candidates.reserveCapacity(min(stations.count, rawCandidateLimit))

        for radiusKm in radiusSteps {
            candidates.removeAll(keepingCapacity: true)

            for station in stations {
                guard station.hasValidCoordinate else { continue }
                guard isInsideBoundingBox(station: station, origin: origin, radiusKm: radiusKm) else { continue }
                guard filters.minimumPowerKW <= 0 || !station.hasKnownPower || station.powerKW >= filters.minimumPowerKW else { continue }
                guard filters.socketFilters.isEmpty || !station.hasKnownSocket || filters.socketFilters.contains(where: { station.socket.localizedCaseInsensitiveContains($0) }) else { continue }
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

    public func candidatesAlongJourney(
        from stations: [Station],
        origin: UserLocation,
        destination: JourneyDestination,
        routePoints: [UserLocation] = [],
        profile: DrivingProfile,
        filters: StationFilters,
        stationStatuses: [String: StationStatusSummary] = [:],
        limit: Int = 80
    ) -> [StationCandidate] {
        let normalizedSearch = filters.searchText.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "tr_TR")
        )
        let destinationLocation = UserLocation(
            latitude: destination.latitude,
            longitude: destination.longitude,
            source: .manual
        )
        let route = normalizedRoutePoints(
            origin: origin,
            routePoints: routePoints,
            destination: destinationLocation
        )
        let routeDistance = routeDistanceKm(route)
        let corridorRadiusKm = min(30, max(5, routeDistance * 0.08))
        let bounds = routeBounds(route, paddingKm: corridorRadiusKm)

        let candidates = stations.compactMap { station -> StationCandidate? in
            guard station.hasValidCoordinate else { return nil }
            guard bounds.contains(latitude: station.latitude, longitude: station.longitude) else { return nil }
            guard filters.minimumPowerKW <= 0 || !station.hasKnownPower || station.powerKW >= filters.minimumPowerKW else { return nil }
            guard filters.socketFilters.isEmpty || !station.hasKnownSocket || filters.socketFilters.contains(where: { station.socket.localizedCaseInsensitiveContains($0) }) else { return nil }
            guard filters.operatorFilters.isEmpty || filters.operatorFilters.contains(station.operatorName) else { return nil }
            guard normalizedSearch.isEmpty || station.searchableText.contains(normalizedSearch) else { return nil }

            guard let routePosition = closestRoutePosition(
                latitude: station.latitude,
                longitude: station.longitude,
                route: route
            ) else { return nil }
            guard routePosition.lateralDistanceKm <= corridorRadiusKm else { return nil }

            let fromOriginStraight = DistanceCalculator.haversineKm(
                from: origin,
                toLatitude: station.latitude,
                longitude: station.longitude
            )
            let estimatedDistance = routePosition.distanceFromOriginKm
                + DistanceCalculator.estimatedRoadDistanceKm(straightLineKm: routePosition.lateralDistanceKm)
            guard !filters.rangeFilterEnabled || estimatedDistance <= profile.safeRangeKm else { return nil }
            let deviation = routePosition.lateralDistanceKm * 2

            var candidate = StationCandidate(
                station: station,
                status: stationStatuses[station.statusKey] ?? stationStatuses[station.id],
                distanceKm: (estimatedDistance * 10).rounded() / 10,
                straightLineDistanceKm: (fromOriginStraight * 10).rounded() / 10,
                estimatedMinutes: DistanceCalculator.estimatedMinutes(distanceKm: estimatedDistance),
                arrivalChargePercent: profile.arrivalChargePercent(distanceKm: estimatedDistance),
                remainingSafeRangeKm: max(0, profile.safeRangeKm - estimatedDistance),
                routeDeviationKm: (deviation * 10).rounded() / 10,
                score: 1,
                badges: []
            )
            candidate.score = max(1, StationScorer.score(candidate: candidate) - Int(deviation.rounded()))
            candidate.badges = StationScorer.badges(for: candidate)
            return candidate
        }

        return candidates.sorted(preference: filters.preference).prefix(limit).map { $0 }
    }

    private func radiusSteps(rangeFilterEnabled: Bool, safeRangeKm: Double) -> [Double] {
        var radius = max(20, rangeFilterEnabled ? safeRangeKm : defaultCandidateRadiusKm)
        var steps: [Double] = []

        if rangeFilterEnabled {
            return [min(radius, maxCandidateRadiusKm)]
        }

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

    private func normalizedRoutePoints(
        origin: UserLocation,
        routePoints: [UserLocation],
        destination: UserLocation
    ) -> [UserLocation] {
        var points = [origin]
        points.append(contentsOf: routePoints.filter {
            (-90...90).contains($0.latitude) && (-180...180).contains($0.longitude)
        })
        points.append(destination)
        return points.reduce(into: []) { result, point in
            guard let last = result.last else {
                result.append(point)
                return
            }
            if abs(last.latitude - point.latitude) > 0.00001
                || abs(last.longitude - point.longitude) > 0.00001 {
                result.append(point)
            }
        }
    }

    private func routeDistanceKm(_ route: [UserLocation]) -> Double {
        zip(route, route.dropFirst()).reduce(0) { distance, pair in
            distance + DistanceCalculator.haversineKm(
                from: pair.0,
                toLatitude: pair.1.latitude,
                longitude: pair.1.longitude
            )
        }
    }

    private func routeBounds(_ route: [UserLocation], paddingKm: Double) -> RouteBounds {
        let latitudes = route.map(\.latitude)
        let longitudes = route.map(\.longitude)
        let latitudePadding = paddingKm / 111
        let middleLatitude = ((latitudes.min() ?? 0) + (latitudes.max() ?? 0)) / 2
        let longitudePadding = paddingKm / (111 * max(0.18, abs(cos(middleLatitude * .pi / 180))))
        return RouteBounds(
            minimumLatitude: (latitudes.min() ?? -90) - latitudePadding,
            maximumLatitude: (latitudes.max() ?? 90) + latitudePadding,
            minimumLongitude: (longitudes.min() ?? -180) - longitudePadding,
            maximumLongitude: (longitudes.max() ?? 180) + longitudePadding
        )
    }

    private func closestRoutePosition(
        latitude: Double,
        longitude: Double,
        route: [UserLocation]
    ) -> RoutePosition? {
        guard route.count >= 2 else { return nil }
        var best: RoutePosition?
        var cumulativeDistance = 0.0

        for (start, end) in zip(route, route.dropFirst()) {
            let segmentDistance = DistanceCalculator.haversineKm(
                from: start,
                toLatitude: end.latitude,
                longitude: end.longitude
            )
            guard segmentDistance > 0.001 else { continue }
            let progress = projectionProgress(
                latitude: latitude,
                longitude: longitude,
                start: start,
                end: end
            )
            let projected = UserLocation(
                latitude: start.latitude + (end.latitude - start.latitude) * progress,
                longitude: start.longitude + (end.longitude - start.longitude) * progress,
                source: .manual
            )
            let lateralDistance = DistanceCalculator.haversineKm(
                from: projected,
                toLatitude: latitude,
                longitude: longitude
            )
            let position = RoutePosition(
                lateralDistanceKm: lateralDistance,
                distanceFromOriginKm: cumulativeDistance + segmentDistance * progress
            )
            if best == nil || position.lateralDistanceKm < best!.lateralDistanceKm {
                best = position
            }
            cumulativeDistance += segmentDistance
        }
        return best
    }

    private func projectionProgress(
        latitude: Double,
        longitude: Double,
        start: UserLocation,
        end: UserLocation
    ) -> Double {
        let referenceLatitude = (start.latitude + end.latitude) / 2 * .pi / 180
        let scaleX = cos(referenceLatitude)
        let ax = start.longitude * scaleX
        let ay = start.latitude
        let bx = end.longitude * scaleX
        let by = end.latitude
        let px = longitude * scaleX
        let py = latitude
        let dx = bx - ax
        let dy = by - ay
        let denominator = dx * dx + dy * dy
        guard denominator > 0 else { return 0 }
        return min(1, max(0, ((px - ax) * dx + (py - ay) * dy) / denominator))
    }
}

private struct RouteBounds {
    var minimumLatitude: Double
    var maximumLatitude: Double
    var minimumLongitude: Double
    var maximumLongitude: Double

    func contains(latitude: Double, longitude: Double) -> Bool {
        (minimumLatitude...maximumLatitude).contains(latitude)
            && (minimumLongitude...maximumLongitude).contains(longitude)
    }
}

private struct RoutePosition {
    var lateralDistanceKm: Double
    var distanceFromOriginKm: Double
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
