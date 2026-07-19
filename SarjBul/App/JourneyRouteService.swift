import MapKit
import SarjBulCore

actor JourneyRouteService {
    func corridorPoints(
        origin: UserLocation,
        destination: JourneyDestination,
        maximumPointCount: Int = 96
    ) async throws -> [UserLocation] {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: origin.latitude,
            longitude: origin.longitude
        )))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: destination.latitude,
            longitude: destination.longitude
        )))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        guard let route = try await MKDirections(request: request).calculate().routes.first else { return [] }
        let polyline = route.polyline
        guard polyline.pointCount > 0 else { return [] }

        let step = max(1, polyline.pointCount / maximumPointCount)
        let points = polyline.points()
        var result: [UserLocation] = []
        result.reserveCapacity(min(maximumPointCount + 2, polyline.pointCount))

        for index in stride(from: 0, to: polyline.pointCount, by: step) {
            let coordinate = points[index].coordinate
            result.append(UserLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                source: .manual
            ))
        }

        if let last = result.last,
           abs(last.latitude - destination.latitude) > 0.0001
            || abs(last.longitude - destination.longitude) > 0.0001 {
            result.append(UserLocation(
                latitude: destination.latitude,
                longitude: destination.longitude,
                source: .manual
            ))
        }
        return result
    }
}
