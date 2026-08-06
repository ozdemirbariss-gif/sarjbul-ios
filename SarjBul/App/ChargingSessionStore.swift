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

struct PersistedChargingSession: Codable, Equatable, Sendable {
    var station: Station
    var endDate: Date
    var targetPercent: Int
    var startedAt: Date? = nil
    var initialPercent: Int? = nil
    var languageCode: String? = nil
}

@MainActor
@Observable
final class ChargingSessionStore {
    private let poiService = ChargingBreakPOIService()
    private let persistence: any AppPersistence
    private var prepared = false

    private(set) var station: Station?
    private(set) var endDate: Date?
    private(set) var nearbyPlaces: [ChargingBreakPlace] = []
    private(set) var isLoadingPlaces = false
    private(set) var targetPercent = 80
    private(set) var startedAt: Date?
    private(set) var initialPercent = 20
    private(set) var languageCode = "tr"

    init(persistence: any AppPersistence) {
        self.persistence = persistence
        guard let saved = persistence.activeChargingSession, saved.endDate > Date() else {
            persistence.activeChargingSession = nil
            return
        }
        station = saved.station
        endDate = saved.endDate
        targetPercent = saved.targetPercent
        startedAt = saved.startedAt ?? Date()
        initialPercent = saved.initialPercent ?? 20
        languageCode = saved.languageCode ?? "tr"
    }

    var isActive: Bool { station != nil && endDate != nil }

    func prepare() async {
        guard !prepared else { return }
        prepared = true
        guard let station, let endDate, let startedAt, endDate > Date() else {
            persistence.activeChargingSession = nil
            return
        }
        await loadPlaces(near: station)
        await ChargingActivityManager.shared.start(
            stationName: station.name,
            startedAt: startedAt,
            endDate: endDate,
            initialPercent: initialPercent,
            targetPercent: targetPercent,
            languageCode: languageCode
        )
        saveWidgetContext(station: station, endDate: endDate)
    }

    func start(
        station: Station,
        minutes: Int = 30,
        initialPercent: Int = 20,
        targetPercent: Int = 80,
        languageCode: String = "tr"
    ) async {
        self.station = station
        let startedAt = Date()
        let endDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        self.startedAt = startedAt
        self.endDate = endDate
        self.initialPercent = initialPercent
        self.targetPercent = targetPercent
        self.languageCode = languageCode
        persistence.activeChargingSession = PersistedChargingSession(
            station: station,
            endDate: endDate,
            targetPercent: targetPercent,
            startedAt: startedAt,
            initialPercent: initialPercent,
            languageCode: languageCode
        )
        await loadPlaces(near: station)
        await ChargingActivityManager.shared.start(
            stationName: station.name,
            startedAt: startedAt,
            endDate: endDate,
            initialPercent: initialPercent,
            targetPercent: targetPercent,
            languageCode: languageCode
        )
        saveWidgetContext(station: station, endDate: endDate)
    }

    func stop() async {
        station = nil
        endDate = nil
        startedAt = nil
        nearbyPlaces = []
        persistence.activeChargingSession = nil
        WidgetContextSnapshotStore.clear(kind: .activeCharging)
        await ChargingActivityManager.shared.stop()
    }

    private func saveWidgetContext(station: Station, endDate: Date) {
        let isEnglish = languageCode == "en"
        WidgetContextSnapshotStore.save(WidgetContextSnapshot(
            kind: .activeCharging,
            title: isEnglish ? "Charging" : "Şarj devam ediyor",
            subtitle: station.name,
            value: "%\(targetPercent)",
            icon: "bolt.fill",
            deepLink: "sarjbul://lounge",
            updatedAt: Date(),
            endDate: endDate
        ))
    }

    private func loadPlaces(near station: Station) async {
        isLoadingPlaces = true
        nearbyPlaces = await poiService.places(near: station, radiusMeters: 400)
        isLoadingPlaces = false
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
