import CarPlay
import CoreLocation
import SarjBulCore
@testable import SarjBul
import XCTest

@MainActor
final class CarPlayTests: XCTestCase {
    func testMapPointsAreLimitedAndDoNotIncludeInvalidOrDistantStations() {
        var values = (0..<20).map { candidate(id: "\($0)") }
        var invalid = candidate(id: "invalid")
        invalid.station.latitude = 100
        var distant = candidate(id: "far")
        distant.straightLineDistanceKm = 81
        values.insert(contentsOf: [invalid, distant, values[0]], at: 0)
        let visible = CarPlayStationPresenter.visibleCandidates(values)
        XCTAssertEqual(visible.count, 12)
        XCTAssertEqual(Set(visible.map(\.station.statusKey)).count, 12)
        XCTAssertFalse(visible.contains { $0.id == "invalid" || $0.id == "far" })
    }

    func testOnlyFreshDeviceLocationIsUsedForNearbyChargers() {
        let now = Date()
        let fresh = UserLocation(latitude: 38.4, longitude: 27.1, source: .device, capturedAt: now)
        XCTAssertEqual(CarPlayStationPresenter.currentLocation(fresh, authorization: .authorizedWhenInUse, now: now), fresh)
        XCTAssertEqual(CarPlayStationPresenter.currentLocation(fresh, authorization: .authorizedAlways, now: now), fresh)
        for authorization in [CLAuthorizationStatus.denied, .restricted, .notDetermined] {
            XCTAssertNil(CarPlayStationPresenter.currentLocation(fresh, authorization: authorization, now: now))
        }
        for value in [
            UserLocation(latitude: 38.4, longitude: 27.1, source: .manual, capturedAt: now),
            UserLocation(latitude: 38.4, longitude: 27.1, source: .device, capturedAt: now.addingTimeInterval(-121)),
            UserLocation(latitude: 38.4, longitude: 27.1, source: .device, capturedAt: now.addingTimeInterval(10)),
            UserLocation(latitude: 100, longitude: 27.1, source: .device, capturedAt: now)
        ] { XCTAssertNil(CarPlayStationPresenter.currentLocation(value, authorization: .authorizedWhenInUse, now: now)) }
        XCTAssertNil(CarPlayStationPresenter.currentLocation(nil, authorization: .authorizedAlways, now: now))
    }

    func testChargerPointUsesSystemDetailsAndDirectionsActions() {
        let station = candidate(id: "station").station
        let point = CarPlayStationPresenter.point(station: station, language: .en, directions: {}, details: {})
        XCTAssertEqual(point.title, station.name)
        XCTAssertEqual(point.userInfo as? String, station.statusKey)
        XCTAssertEqual(point.location.placemark.coordinate.latitude, station.latitude)
        XCTAssertEqual(point.primaryButton?.title, "Go with Apple Maps")
        XCTAssertEqual(point.secondaryButton?.title, "Details")
    }

    func testCatalogDateIsNeverPresentedAsTariffConfirmation() {
        var station = candidate(id: "station").station
        station.sourceObservedAt = "2026-10-09T09:00:00Z"
        let evidence = StationEvidenceText(station: station, insight: nil, live: nil, risky: false, language: .en)
        XCTAssertEqual(evidence.price, "Unknown")
        XCTAssertTrue(evidence.priceSource.contains("EPDK"))
        XCTAssertTrue(evidence.priceSource.contains("Price date: Unknown"))
        XCTAssertTrue(evidence.availability.contains("Availability unknown"))
    }

    func testOperatorSnapshotExpiresEvenWhileDetailsStayOpen() {
        let now = Date()
        let station = candidate(id: "station").station
        let live = LiveStationAvailability(stationKey: station.statusKey, availableConnectors: 1, totalConnectors: 2, updatedAt: now)
        var evidence = StationEvidenceText(station: station, insight: nil, live: live, risky: false, language: .en, now: now)
        XCTAssertTrue(evidence.availability.contains("Operator feed"))
        evidence.now = now.addingTimeInterval(901)
        XCTAssertTrue(evidence.availability.contains("Availability unknown"))
        evidence.now = now.addingTimeInterval(-1)
        XCTAssertTrue(evidence.availability.contains("Availability unknown"))
    }

    func testRiskReportDoesNotImplyCurrentOperatorStatus() {
        let evidence = StationEvidenceText(station: candidate(id: "station").station, insight: nil, live: nil, risky: true, language: .tr)
        XCTAssertTrue(evidence.availability.contains("güncelliği bilinmiyor"))
    }

    func testCarPlaySceneIsRegisteredAlongsideSwiftUI() throws {
        let manifest = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") as? [String: Any])
        XCTAssertEqual(manifest["UIApplicationSupportsMultipleScenes"] as? Bool, true)
        let roles = try XCTUnwrap(manifest["UISceneConfigurations"] as? [String: Any])
        let scenes = try XCTUnwrap(roles[UISceneSession.Role.carTemplateApplication.rawValue] as? [[String: Any]])
        XCTAssertEqual(scenes.first?["UISceneClassName"] as? String, "CPTemplateApplicationScene")
        XCTAssertEqual(scenes.first?["UISceneDelegateClassName"] as? String, "SarjBul.CarPlaySceneDelegate")
    }

    private func candidate(id: String) -> StationCandidate {
        StationCandidate(station: Station(id: id, name: id, address: "İzmir", latitude: 38.4 + (Double(id) ?? 0) * 0.001,
                                         longitude: 27.1, power: "180 kW", operatorName: "Test operator", socket: "CCS", price: "Bilinmiyor", source: "EPDK"),
                         distanceKm: 1, straightLineDistanceKm: 1, estimatedMinutes: 1, arrivalChargePercent: 50,
                         remainingSafeRangeKm: 100, score: 1, badges: [])
    }
}
