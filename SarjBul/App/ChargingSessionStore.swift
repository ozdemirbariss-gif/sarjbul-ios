@preconcurrency import MapKit
import Observation
import SarjBulCore

struct ChargingBreakPlace: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var category: String
    var distanceMeters: Int
    var coordinate: CLLocationCoordinate2D

    static func == (lhs: ChargingBreakPlace, rhs: ChargingBreakPlace) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@MainActor
@Observable
final class ChargingSessionStore {
    private let poiService = ChargingBreakPOIService()

    private(set) var station: Station?
    private(set) var endDate: Date?
    private(set) var nearbyPlaces: [ChargingBreakPlace] = []
    private(set) var isLoadingPlaces = false

    var isActive: Bool { station != nil && endDate != nil }

    func start(station: Station, minutes: Int = 30, targetPercent: Int = 80) async {
        self.station = station
        endDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        isLoadingPlaces = true
        nearbyPlaces = await poiService.places(near: station, radiusMeters: 400)
        isLoadingPlaces = false
        await ChargingActivityManager.shared.start(
            stationName: station.name,
            minutes: minutes,
            targetPercent: targetPercent
        )
    }

    func stop() async {
        station = nil
        endDate = nil
        nearbyPlaces = []
        await ChargingActivityManager.shared.stop()
    }
}

private actor ChargingBreakPOIService {
    func places(near station: Station, radiusMeters: Double) async -> [ChargingBreakPlace] {
        let center = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )
        let queries = ["kahve", "market", "park", "fırın", "tuvalet"]
        var places: [ChargingBreakPlace] = []
        for query in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            guard let response = try? await MKLocalSearch(request: request).start() else { continue }
            for item in response.mapItems.prefix(3) {
                let coordinate = item.placemark.coordinate
                let distance = CLLocation(latitude: station.latitude, longitude: station.longitude)
                    .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                guard distance <= radiusMeters else { continue }
                let name = item.name ?? query.capitalized
                places.append(ChargingBreakPlace(
                    id: "\(name)-\(coordinate.latitude)-\(coordinate.longitude)",
                    name: name,
                    category: query.capitalized,
                    distanceMeters: Int(distance.rounded()),
                    coordinate: coordinate
                ))
            }
        }
        var seen = Set<String>()
        return places
            .sorted { $0.distanceMeters < $1.distanceMeters }
            .filter { seen.insert($0.id).inserted }
            .prefix(8)
            .map { $0 }
    }
}
