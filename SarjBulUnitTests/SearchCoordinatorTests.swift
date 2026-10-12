import Foundation
import MapKit
import SarjBulCore
import XCTest
@testable import SarjBul

@MainActor
final class SearchCoordinatorTests: XCTestCase {
    func testUnmatchedFiltersNeverSilentlyReturnOtherStations() async throws {
        let app = try makeApp(repository: SearchTestRepository())
        app.search.updateLocation(latitude: 38.4, longitude: 27.1, source: .manual)
        app.settings.filters.minimumPowerKW = 350
        app.settings.filters.socketFilters = ["Type 2"]
        let original = app.settings.filters
        await app.search.findStations()
        XCTAssertTrue(app.search.routeCandidates.isEmpty)
        XCTAssertNil(app.search.preparedCandidate)
        XCTAssertEqual(app.settings.filters, original)
        XCTAssertFalse(app.search.locationNeedsReview)
    }

    func testMovingLocationImmediatelyClearsPreparedAndPreviousResults() async throws {
        let app = try makeApp(repository: SearchTestRepository())
        app.search.updateLocation(latitude: 38.4, longitude: 27.1, source: .manual)
        await app.search.prepareOutcome()
        XCTAssertEqual(app.search.preparedCandidate?.station.id, "izmir")
        app.search.updateLocation(latitude: 39.93, longitude: 32.86, source: .manual)
        XCTAssertNil(app.search.preparedCandidate)
        XCTAssertTrue(app.search.previousCandidates.isEmpty)
        XCTAssertTrue(app.search.routeCandidates.isEmpty)
    }

    func testNewLocationWinsWhileOlderSearchIsSuspended() async throws {
        let repository = SuspendedSearchRepository()
        let app = try makeApp(repository: repository)
        app.search.updateLocation(latitude: 38.4, longitude: 27.1, source: .manual)
        let older = Task { await app.search.prepareOutcome() }
        await repository.waitUntilStarted()
        app.search.updateLocation(latitude: 39.93, longitude: 32.86, source: .manual)
        let newer = Task { await app.search.prepareOutcome() }
        await repository.release()
        await newer.value
        await older.value
        XCTAssertEqual(app.search.preparedCandidate?.station.id, "ankara")
        XCTAssertEqual(app.search.previousCandidates.first?.station.id, "ankara")
    }

    func testResetPreventsSuspendedSearchFromPublishing() async throws {
        let repository = SuspendedSearchRepository()
        let app = try makeApp(repository: repository)
        app.search.updateLocation(latitude: 38.4, longitude: 27.1, source: .manual)
        let search = Task { await app.search.findStations() }
        await repository.waitUntilStarted()
        app.search.reset()
        await repository.release()
        await search.value
        XCTAssertNil(app.search.preparedCandidate)
        XCTAssertTrue(app.search.previousCandidates.isEmpty)
        XCTAssertFalse(app.search.isSearching)
    }

    func testChangingFiltersHidesOldPreparedResultAndUsesNewContext() async throws {
        let app = try makeApp(repository: SearchTestRepository())
        app.search.updateLocation(latitude: 38.4, longitude: 27.1, source: .manual)
        await app.search.prepareOutcome()
        XCTAssertEqual(app.search.preparedCandidate?.station.id, "izmir")
        app.settings.filters.operatorFilters = ["Ankara Operator"]
        app.settings.filters.rangeFilterEnabled = false
        XCTAssertNil(app.search.preparedCandidate)
        await app.search.prepareOutcome()
        XCTAssertEqual(app.search.routeCandidates.first?.station.id, "ankara")
        XCTAssertNil(app.search.preparedCandidate)
    }

    func testActualRoadDistanceCanRejectAnApparentlyNearbyStation() async throws {
        let routes = RouteStore { _, station in
            StationRoute(stationID: station.id, distanceKm: 300, expectedTravelTime: 10_800,
                         polyline: MKPolyline(), steps: [])
        }
        let app = try makeApp(repository: SearchTestRepository(), routeStore: routes)
        app.search.updateLocation(latitude: 38.4, longitude: 27.1, source: .manual)
        await app.search.prepareOutcome()
        XCTAssertTrue(app.search.routeCandidates.isEmpty)
        XCTAssertNil(app.search.preparedCandidate)
    }

    func testUnavailableRoadRouteCannotBecomeAPreparedRecommendation() async throws {
        let app = try makeApp(repository: SearchTestRepository(), routeStore: RouteStore { _, _ in nil })
        app.search.updateLocation(latitude: 38.4, longitude: 27.1, source: .manual)
        await app.search.prepareOutcome()
        XCTAssertNil(app.search.preparedCandidate)
    }

    func testRealtimeFaultReranksPreviouslyPreparedChoice() async throws {
        let routes = RouteStore { _, station in
            StationRoute(stationID: station.id, distanceKm: station.id == "izmir" ? 1 : 2,
                         expectedTravelTime: 120, polyline: MKPolyline(), steps: [])
        }
        let app = try makeApp(repository: SearchTestRepository(), routeStore: routes)
        app.settings.filters.rangeFilterEnabled = false
        app.search.updateLocation(latitude: 38.4, longitude: 27.1, source: .manual)
        await app.search.prepareOutcome()
        XCTAssertEqual(app.search.preparedCandidate?.station.id, "izmir")
        app.search.applyRealtime(.statusChanged(key: SearchTestRepository.stations[0].statusKey,
                                               value: StationStatusSummary(durum: "riskli")))
        XCTAssertEqual(app.search.preparedCandidate?.station.id, "ankara")
        XCTAssertEqual(app.search.previousCandidates.first?.station.id, "ankara")
    }

    func testAllRiskyStationsCannotBecomePreparedRecommendations() async throws {
        let app = try makeApp(repository: SearchTestRepository())
        app.search.updateLocation(latitude: 38.4, longitude: 27.1, source: .manual)
        await app.search.prepareOutcome()
        app.search.applyRealtime(.statusChanged(key: SearchTestRepository.stations[0].statusKey,
                                               value: StationStatusSummary(durum: "riskli")))
        XCTAssertNil(app.search.preparedCandidate)
    }

    func testRoadValidationRetriesAlternativeStopsAndUsesMeasuredLegs() async throws {
        let stations = SearchTestRepository.stations
        var measuredStationIDs: [String] = []
        let routes = RouteStore { origin, station in
            measuredStationIDs.append(station.id)
            // The first estimated stop cannot be reached by road; the alternative can.
            let distance: Double
            if station.id == "izmir" {
                distance = 200
            } else if station.id == "ankara" {
                distance = 80
            } else {
                distance = origin.latitude == stations[1].latitude ? 120 : 200
            }
            return StationRoute(stationID: station.id, distanceKm: distance,
                                expectedTravelTime: distance * 60, polyline: MKPolyline(), steps: [])
        }
        func candidate(_ original: Station, _ distance: Double) -> StationCandidate {
            var station = original
            if station.id == "izmir" {
                station.power = "350 kW"
                station.chargingUnits = [.init(id: "dc", powerKW: 350, sockets: [.init(id: "ccs", type: "CCS")])]
            }
            return StationCandidate(station: station, distanceKm: distance, straightLineDistanceKm: distance,
                             estimatedMinutes: 60, arrivalChargePercent: 20, remainingSafeRangeKm: 20,
                             score: 50, badges: [])
        }
        let result = await RoadRouteValidator(routes: routes).plan(
            snapshot: JourneyRouteSnapshot(points: [], distanceKm: 200, estimatedMinutes: 200, elevation: .init()),
            origin: UserLocation(latitude: 38, longitude: 27, source: .manual),
            destination: JourneyDestination(name: "End", address: "Test", latitude: 40, longitude: 34),
            candidates: [candidate(stations[0], 70), candidate(stations[1], 90)],
            profile: DrivingProfile(batteryKWh: 50, chargePercent: 50, consumptionKWhPer100Km: 20, maximumDCPowerKW: 350)
        )
        XCTAssertTrue(measuredStationIDs.contains("izmir"))
        XCTAssertEqual(result?.stops.first?.id, "ankara")
        XCTAssertEqual(result?.distanceKm, 200)
        XCTAssertEqual(result?.drivingMinutes, 200)
    }

    func testDeviceTimestampIsPreserved() throws {
        let app = try makeApp(repository: SearchTestRepository())
        let observed = Date().addingTimeInterval(-300)
        app.search.updateLocation(latitude: 38.4, longitude: 27.1, source: .device, capturedAt: observed)
        XCTAssertEqual(app.search.userLocation?.capturedAt, observed)
    }

    func testAppleSearchCoordinatesAreOnlyPassedToAppleMaps() throws {
        let origin = UserLocation(latitude: 38.4, longitude: 27.1, source: .appleMaps)
        let station = SearchTestRepository.stations[0]
        let appleItems = ExternalNavigationHandoff.appleMapItems(origin: origin, destination: station)
        XCTAssertEqual(appleItems.count, 2)
        XCTAssertEqual(appleItems[0].placemark.coordinate.latitude, origin.latitude, accuracy: 0.000_001)
        let url = try XCTUnwrap(ExternalNavigationHandoff.googleMapsURL(origin: origin, destination: station))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertFalse(components.queryItems?.contains { $0.name == "origin" } ?? false)
        XCTAssertTrue(components.queryItems?.contains { $0.name == "destination" } ?? false)
    }

    func testManualOriginIsIncludedInExternalMapHandoffs() throws {
        let origin = UserLocation(latitude: 38.3939, longitude: 27.1891, source: .manual)
        let station = SearchTestRepository.stations[0]

        let appleItems = ExternalNavigationHandoff.appleMapItems(origin: origin, destination: station)
        XCTAssertEqual(appleItems.count, 2)
        XCTAssertEqual(appleItems[0].placemark.coordinate.latitude, origin.latitude, accuracy: 0.000_001)
        XCTAssertEqual(appleItems[0].placemark.coordinate.longitude, origin.longitude, accuracy: 0.000_001)

        let url = try XCTUnwrap(ExternalNavigationHandoff.googleMapsURL(origin: origin, destination: station))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        XCTAssertEqual(values["origin"], "38.3939,27.1891")
        XCTAssertEqual(values["dir_action"], "navigate")
    }

    func testDeviceOriginUsesLiveLocationForExternalMapHandoffs() throws {
        let origin = UserLocation(latitude: 38.3939, longitude: 27.1891, source: .device)
        let station = SearchTestRepository.stations[0]

        let appleItems = ExternalNavigationHandoff.appleMapItems(origin: origin, destination: station)
        XCTAssertEqual(appleItems.count, 2)
        XCTAssertTrue(appleItems[0].isCurrentLocation)

        let url = try XCTUnwrap(ExternalNavigationHandoff.googleMapsURL(origin: origin, destination: station))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertFalse((components.queryItems ?? []).contains { $0.name == "origin" })
    }

    private func makeApp(repository: any StationRepository, routeStore: RouteStore? = nil) throws -> AppState {
        let name = "SearchCoordinatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        let persistence = SystemAppPersistence(defaults: defaults, secureStorage: SearchTestSecureStorage())
        let app = AppState(repository: repository, clients: AppServiceClients(
            auth: UnavailableAuthClient(), favorites: UnavailableFavoritesClient(),
            status: UnavailableStatusClient(), demandAnalytics: UnavailableDemandAnalyticsClient(),
            realtime: UnavailableRealtimeStationClient(), pushTokens: UnavailablePushTokenClient(),
            liveAvailability: UnavailableLiveAvailabilityClient(), isConfigured: false
        ), persistence: persistence, externalLinks: .empty, routeStore: routeStore ?? RouteStore { origin, station in
            let distance = DistanceCalculator.estimatedRoadDistanceKm(straightLineKm: DistanceCalculator.haversineKm(
                from: origin, toLatitude: station.latitude, longitude: station.longitude
            ))
            return StationRoute(stationID: station.id, distanceKm: distance, expectedTravelTime: distance * 60,
                                polyline: MKPolyline(), steps: [])
        })
        app.settings.filters = StationFilters(preference: .nearest)
        return app
    }
}

private struct SearchTestRepository: StationRepository {
    static let stations = [
        Station(id: "izmir", name: "Izmir", address: "Test", latitude: 38.4, longitude: 27.1,
                power: "50 kW", operatorName: "Izmir Operator", socket: "CCS", price: "10 TL", source: "test"),
        Station(id: "ankara", name: "Ankara", address: "Test", latitude: 39.93, longitude: 32.86,
                power: "150 kW", operatorName: "Ankara Operator", socket: "CCS", price: "10 TL", source: "test")
    ]
    func loadStations() async throws -> [Station] { Self.stations }
}

private actor SuspendedSearchRepository: StationRepository {
    private var started = false
    private var released = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?
    func loadStations() async throws -> [Station] {
        started = true
        startWaiter?.resume()
        startWaiter = nil
        if !released { await withCheckedContinuation { releaseWaiter = $0 } }
        return SearchTestRepository.stations
    }
    func waitUntilStarted() async {
        if !started { await withCheckedContinuation { startWaiter = $0 } }
    }
    func release() {
        released = true
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

private final class SearchTestSecureStorage: SecureStorage {
    private var values: [String: Data] = [:]
    func data(for key: String) -> Data? { values[key] }
    func set(_ data: Data, for key: String) { values[key] = data }
    func remove(_ key: String) { values[key] = nil }
}
