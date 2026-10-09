import CarPlay
import MapKit
import SarjBulCore

@MainActor
enum CarPlayStationPresenter {
    static let maximumPoints = 12
    static let radiusKm = 80.0

    static func currentLocation(_ location: UserLocation?, authorization: CLAuthorizationStatus, now: Date = Date()) -> UserLocation? {
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways,
              let location, location.source == .device,
              location.isFresh(at: now, maximumAge: 120),
              CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) else { return nil }
        return location
    }

    static func visibleCandidates(_ candidates: [StationCandidate]) -> [StationCandidate] {
        var seen = Set<String>()
        return Array(candidates.filter {
            $0.station.hasValidCoordinate && $0.straightLineDistanceKm <= radiusKm
                && seen.insert($0.station.statusKey).inserted
        }.prefix(maximumPoints))
    }

    static func point(
        station: Station,
        language: AppLanguage,
        directions: @escaping @MainActor () -> Void,
        details: @escaping @MainActor () -> Void
    ) -> CPPointOfInterest {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)))
        item.name = station.name
        let point = CPPointOfInterest(
            location: item, title: station.name, subtitle: station.operatorName,
            summary: station.socket + " · " + station.power,
            detailTitle: station.name, detailSubtitle: station.address,
            detailSummary: station.socket + " · " + station.power,
            pinImage: UIImage(systemName: "bolt.car.fill")
        )
        point.userInfo = station.statusKey
        point.primaryButton = CPTextButton(title: AppLocalization.text("carplay.directions", language: language), textStyle: .confirm) { _ in directions() }
        point.secondaryButton = CPTextButton(title: AppLocalization.text("carplay.details", language: language), textStyle: .normal) { _ in details() }
        return point
    }
}
