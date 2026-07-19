@preconcurrency import MapKit
import Observation
import SarjBulCore

@MainActor
@Observable
final class RouteStore {
    private var routes: [RouteKey: StationRoute] = [:]
    private var failures: Set<RouteKey> = []

    func cachedRoute(origin: UserLocation, station: Station) -> StationRoute? {
        routes[RouteKey(origin: origin, stationID: station.id)]
    }

    func route(origin: UserLocation, station: Station) async -> StationRoute? {
        let key = RouteKey(origin: origin, stationID: station.id)
        if let cached = routes[key] { return cached }
        if failures.contains(key) { return nil }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: origin.latitude,
            longitude: origin.longitude
        )))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: station.latitude,
            longitude: station.longitude
        )))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        do {
            guard let route = try await MKDirections(request: request).calculate().routes.first else {
                failures.insert(key)
                return nil
            }
            let result = StationRoute(
                stationID: station.id,
                distanceKm: route.distance / 1_000,
                expectedTravelTime: route.expectedTravelTime,
                polyline: route.polyline,
                steps: route.steps.compactMap { step in
                    let instruction = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !instruction.isEmpty else { return nil }
                    return StationRouteStep(
                        instruction: instruction,
                        distanceMeters: step.distance
                    )
                }
            )
            if routes.count >= 96, let oldestKey = routes.keys.first {
                routes.removeValue(forKey: oldestKey)
            }
            routes[key] = result
            return result
        } catch {
            AppLogger.routing.warning("MapKit route failed for \(station.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            failures.insert(key)
            return nil
        }
    }

    func invalidate() {
        routes.removeAll()
        failures.removeAll()
    }
}

struct StationRoute {
    var stationID: String
    var distanceKm: Double
    var expectedTravelTime: TimeInterval
    var polyline: MKPolyline
    var steps: [StationRouteStep]

    var estimatedMinutes: Int {
        max(1, Int((expectedTravelTime / 60).rounded()))
    }
}

struct StationRouteStep: Identifiable {
    let id = UUID()
    var instruction: String
    var distanceMeters: Double
}

private struct RouteKey: Hashable {
    var latitude: Int
    var longitude: Int
    var stationID: String

    init(origin: UserLocation, stationID: String) {
        latitude = Int((origin.latitude * 10_000).rounded())
        longitude = Int((origin.longitude * 10_000).rounded())
        self.stationID = stationID
    }
}
