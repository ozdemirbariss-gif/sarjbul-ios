@preconcurrency import MapKit
import SarjBulCore

actor JourneyRouteService {
    private let elevationService = RouteElevationService()

    func routeSnapshot(
        origin: UserLocation,
        destination: JourneyDestination,
        maximumPointCount: Int = 96
    ) async throws -> JourneyRouteSnapshot {
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

        guard let route = try await MKDirections(request: request).calculate().routes.first else {
            return JourneyRouteSnapshot(points: [], distanceKm: 0, estimatedMinutes: 0, elevation: .init())
        }
        let polyline = route.polyline
        guard polyline.pointCount > 0 else {
            return JourneyRouteSnapshot(
                points: [],
                distanceKm: route.distance / 1_000,
                estimatedMinutes: Int(ceil(route.expectedTravelTime / 60)),
                elevation: .init()
            )
        }

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
        let elevation = (try? await elevationService.profile(for: result)) ?? .init()
        return JourneyRouteSnapshot(
            points: result,
            distanceKm: route.distance / 1_000,
            estimatedMinutes: Int(ceil(route.expectedTravelTime / 60)),
            elevation: elevation
        )
    }
}

struct JourneyRouteSnapshot: Sendable {
    var points: [UserLocation]
    var distanceKm: Double
    var estimatedMinutes: Int
    var elevation: RouteElevationProfile
}

private actor RouteElevationService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func profile(for route: [UserLocation]) async throws -> RouteElevationProfile {
        let sampled = sampledPoints(route, maximumCount: 80)
        guard sampled.count >= 2 else { return .init() }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/elevation")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: sampled.map { String(format: "%.5f", $0.latitude) }.joined(separator: ",")),
            URLQueryItem(name: "longitude", value: sampled.map { String(format: "%.5f", $0.longitude) }.joined(separator: ","))
        ]
        guard let url = components?.url else { return .init() }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("SarjBul-iOS/1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let elevations = try JSONDecoder().decode(ElevationResponse.self, from: data).elevation
        var gain = 0.0
        var loss = 0.0
        for (start, end) in zip(elevations, elevations.dropFirst()) {
            let delta = end - start
            if delta > 0 { gain += delta } else { loss += abs(delta) }
        }
        return RouteElevationProfile(gainMeters: gain, lossMeters: loss)
    }

    private func sampledPoints(_ route: [UserLocation], maximumCount: Int) -> [UserLocation] {
        guard route.count > maximumCount else { return route }
        let strideValue = max(1, route.count / maximumCount)
        var result = Swift.stride(from: 0, to: route.count, by: strideValue).map { route[$0] }
        if result.last != route.last, let last = route.last { result.append(last) }
        return Array(result.prefix(maximumCount))
    }
}

private struct ElevationResponse: Decodable {
    var elevation: [Double]
}
