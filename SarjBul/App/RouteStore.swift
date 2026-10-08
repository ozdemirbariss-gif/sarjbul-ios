@preconcurrency import MapKit
import Observation
import SarjBulCore

@MainActor
@Observable
final class RouteStore {
    private var routes: [RouteKey: StationRoute] = [:]
    private var failures: [RouteKey: Date] = [:]
    private var cachedAt: [RouteKey: Date] = [:]
    private var expiryTasks: [RouteKey: Task<Void, Never>] = [:]
    private var generation = 0
    private let failureRetryInterval: TimeInterval = 30

    func cachedRoute(origin: UserLocation, station: Station) -> StationRoute? {
        let key = RouteKey(origin: origin, stationID: station.id)
        guard let date = cachedAt[key], Date().timeIntervalSince(date) < 5 * 60 else {
            routes.removeValue(forKey: key)
            cachedAt.removeValue(forKey: key)
            return nil
        }
        return routes[key]
    }

    func route(origin: UserLocation, station: Station) async -> StationRoute? {
        let key = RouteKey(origin: origin, stationID: station.id)
        if let cached = cachedRoute(origin: origin, station: station) { return cached }
        if let failedAt = failures[key], Date().timeIntervalSince(failedAt) < failureRetryInterval {
            return nil
        }
        failures.removeValue(forKey: key)
        let requestGeneration = generation

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
                failures[key] = Date()
                return nil
            }
            guard requestGeneration == generation else { return nil }
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
                cachedAt.removeValue(forKey: oldestKey)
                expiryTasks.removeValue(forKey: oldestKey)?.cancel()
            }
            routes[key] = result
            cachedAt[key] = Date()
            expiryTasks.removeValue(forKey: key)?.cancel()
            expiryTasks[key] = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(5 * 60)) } catch { return }
                self?.routes.removeValue(forKey: key)
                self?.cachedAt.removeValue(forKey: key)
                self?.expiryTasks.removeValue(forKey: key)
            }
            return result
        } catch {
            AppLogger.routing.warning("MapKit route failed for \(station.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            failures[key] = Date()
            return nil
        }
    }

    func invalidate() {
        generation += 1
        routes.removeAll()
        failures.removeAll()
        cachedAt.removeAll()
        expiryTasks.values.forEach { $0.cancel() }
        expiryTasks.removeAll()
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
