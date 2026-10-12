import SarjBulCore

@MainActor
final class RoadRouteValidator {
    let routes: RouteStore

    init(routes: RouteStore) { self.routes = routes }

    func candidate(_ candidate: StationCandidate, origin: UserLocation, profile: DrivingProfile) async -> StationCandidate? {
        guard !Task.isCancelled,
              let route = await routes.route(origin: origin, station: candidate.station),
              route.distanceKm.isFinite, route.distanceKm >= 0 else { return nil }
        return candidate.applyingRoadRoute(distanceKm: route.distanceKm, minutes: route.estimatedMinutes, profile: profile)
    }

    func candidates(_ candidates: [StationCandidate], origin: UserLocation, profile: DrivingProfile,
                    rangeFilterEnabled: Bool) async -> [StationCandidate] {
        var result: [StationCandidate] = []
        // Bound MapKit requests; each result uses the same road metrics as its card and handoff.
        for start in stride(from: 0, to: candidates.count, by: 4) {
            guard !Task.isCancelled else { return [] }
            let batch = Array(candidates[start..<min(start + 4, candidates.count)])
            let verified = await withTaskGroup(of: StationCandidate?.self) { group in
                for item in batch {
                    group.addTask { await self.candidate(item, origin: origin, profile: profile) }
                }
                var values: [StationCandidate] = []
                for await item in group {
                    if let item, !rangeFilterEnabled || item.distanceKm <= profile.safeRangeKm { values.append(item) }
                }
                return values
            }
            result.append(contentsOf: verified)
        }
        return result
    }

    func plan(snapshot: JourneyRouteSnapshot, origin: UserLocation, destination: JourneyDestination,
              candidates: [StationCandidate], profile: DrivingProfile) async -> ChargingTripPlan? {
        let planner = ChargingTripPlanner()
        let destinationStation = Station(id: "destination-\(destination.latitude)-\(destination.longitude)",
            name: destination.name, address: destination.address, latitude: destination.latitude,
            longitude: destination.longitude, power: "0", operatorName: "", socket: "", price: "", source: "route")
        var legs = [TripLegKey(from: TripLegKey.origin, to: TripLegKey.destination): TripLegMetrics(
            distanceKm: snapshot.distanceKm, minutes: Double(snapshot.estimatedMinutes)
        )]
        // Replan when a measured leg costs more than its corridor estimate. A failed road
        // request excludes that edge; only a path with every leg measured may be published.
        for _ in 0..<6 {
            guard !Task.isCancelled,
                  let estimate = planner.plan(routeDistanceKm: snapshot.distanceKm, candidates: candidates,
                    profile: profile, estimatedDrivingMinutes: snapshot.estimatedMinutes,
                    elevation: snapshot.elevation, verifiedLegs: legs, requireVerifiedLegs: false) else { return nil }
            var previous = origin
            var previousID = TripLegKey.origin
            var measuredNewLeg = false
            let targets = estimate.stops.map { ($0.id, $0.candidate.station) }
                + [(TripLegKey.destination, destinationStation)]
            for (id, station) in targets {
                let key = TripLegKey(from: previousID, to: id)
                if legs[key] == nil {
                    measuredNewLeg = true
                    guard !Task.isCancelled else { return nil }
                    if let route = await routes.route(origin: previous, station: station) {
                        legs[key] = TripLegMetrics(distanceKm: route.distanceKm, minutes: route.expectedTravelTime / 60)
                    } else { legs[key] = TripLegMetrics(distanceKm: .infinity, minutes: .infinity) }
                }
                previous = UserLocation(latitude: station.latitude, longitude: station.longitude, source: .manual)
                previousID = id
            }
            if !measuredNewLeg {
                return planner.plan(routeDistanceKm: snapshot.distanceKm, candidates: candidates, profile: profile,
                                    elevation: snapshot.elevation, verifiedLegs: legs)
            }
        }
        return nil
    }
}
