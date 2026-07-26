@preconcurrency import MapKit
import SarjBulCore

actor RangeIsochroneService {
    func polygon(origin: UserLocation, rangeKm: Double, rayCount: Int = 16) async -> [CLLocationCoordinate2D] {
        guard rangeKm > 1, rayCount >= 8 else { return [] }
        var coordinates: [CLLocationCoordinate2D] = []
        for index in 0..<rayCount {
            let bearing = Double(index) / Double(rayCount) * 360
            let destination = destinationCoordinate(from: origin, distanceKm: rangeKm, bearingDegrees: bearing)
            if let point = try? await reachablePoint(origin: origin, destination: destination, rangeKm: rangeKm) {
                coordinates.append(point)
            }
        }
        return coordinates.count >= rayCount / 2 ? coordinates : []
    }

    private func reachablePoint(
        origin: UserLocation,
        destination: CLLocationCoordinate2D,
        rangeKm: Double
    ) async throws -> CLLocationCoordinate2D {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: origin.latitude,
            longitude: origin.longitude
        )))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false
        guard let route = try await MKDirections(request: request).calculate().routes.first else { return destination }
        return coordinate(on: route.polyline, atDistanceKm: min(rangeKm, route.distance / 1_000)) ?? destination
    }

    private func coordinate(on polyline: MKPolyline, atDistanceKm target: Double) -> CLLocationCoordinate2D? {
        guard polyline.pointCount > 0 else { return nil }
        let points = polyline.points()
        var travelled = 0.0
        for index in 1..<polyline.pointCount {
            let previous = points[index - 1]
            let current = points[index]
            let segment = previous.distance(to: current) / 1_000
            if travelled + segment >= target {
                let progress = (target - travelled) / max(0.001, segment)
                let start = previous.coordinate
                let end = current.coordinate
                return CLLocationCoordinate2D(
                    latitude: start.latitude + (end.latitude - start.latitude) * progress,
                    longitude: start.longitude + (end.longitude - start.longitude) * progress
                )
            }
            travelled += segment
        }
        return points[polyline.pointCount - 1].coordinate
    }

    private func destinationCoordinate(
        from origin: UserLocation,
        distanceKm: Double,
        bearingDegrees: Double
    ) -> CLLocationCoordinate2D {
        let radius = 6_371.0
        let angularDistance = distanceKm / radius
        let bearing = bearingDegrees * .pi / 180
        let latitude = origin.latitude * .pi / 180
        let longitude = origin.longitude * .pi / 180
        let resultLatitude = asin(
            sin(latitude) * cos(angularDistance)
                + cos(latitude) * sin(angularDistance) * cos(bearing)
        )
        let resultLongitude = longitude + atan2(
            sin(bearing) * sin(angularDistance) * cos(latitude),
            cos(angularDistance) - sin(latitude) * sin(resultLatitude)
        )
        return CLLocationCoordinate2D(
            latitude: resultLatitude * 180 / .pi,
            longitude: resultLongitude * 180 / .pi
        )
    }
}
