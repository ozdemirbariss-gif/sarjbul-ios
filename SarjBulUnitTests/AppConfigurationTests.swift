import Foundation
import XCTest
@testable import SarjBul

@MainActor
final class AppConfigurationTests: XCTestCase {
    func testPublicTileDefaultsDoNotRequestPrivateCanonicalData() throws {
        let configuration = try loadConfiguration(ready: false)
        XCTAssertNil(configuration.stationDataURL)
        XCTAssertEqual(configuration.stationTileManifestURL?.absoluteString,
                       "https://raw.githubusercontent.com/ozdemirbariss-gif/sarjbul-ios/main/SarjBul/Resources/StationTiles/station-tiles-manifest.json")
    }

    func testCredentialsDoNotEnableAnUnverifiedBackend() throws {
        let configuration = try loadConfiguration(ready: nil)
        XCTAssertNotNil(configuration.firebaseDatabaseURL)
        XCTAssertFalse(configuration.firebaseBackendReady)
        XCTAssertFalse(configuration.serviceClients.isConfigured)
    }

    func testExplicitlyDisabledBackendKeepsCloudOperationsUnavailable() throws {
        let configuration = try loadConfiguration(ready: false)
        XCTAssertFalse(configuration.serviceClients.isConfigured)
    }

    func testVerifiedBackendRequiresCredentialsAsWell() throws {
        var configuration = try loadConfiguration(ready: true)
        XCTAssertTrue(configuration.serviceClients.isConfigured)
        configuration.firebaseAPIKey = ""
        XCTAssertFalse(configuration.serviceClients.isConfigured)
        configuration.firebaseAPIKey = "fixture-key"
        configuration.firebaseDatabaseURL = nil
        XCTAssertFalse(configuration.serviceClients.isConfigured)
    }

    func testStationRepositoryRetiresLegacyCachesAndLoadsOnlyEPDK() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "EPDKCache-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyRoot = directory.appending(path: "SarjBul")
        try FileManager.default.createDirectory(at: legacyRoot.appending(path: "StationTiles"), withIntermediateDirectories: true)
        for file in ["StationTiles/station_tile_legacy.json", "stations.json", "stations-metadata.json"] {
            try Data("legacy mixed source cache".utf8).write(to: legacyRoot.appending(path: file))
        }
        // A nearby personal file must survive retirement of the inventory cache.
        let personalFile = legacyRoot.appending(path: "personal-history.json")
        try Data("personal".utf8).write(to: personalFile)
        let configuration = try loadConfiguration(ready: false)
        let repository = try XCTUnwrap(configuration.stationRepository(cacheRoot: directory))
        let stations = try await repository.loadStations()
        XCTAssertGreaterThan(stations.count, 1_000)
        XCTAssertTrue(stations.allSatisfy { $0.source == "epdk" && $0.sources == ["epdk"] && $0.id.hasPrefix("epdk_") })
        for file in ["StationTiles", "stations.json", "stations-metadata.json"] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: legacyRoot.appending(path: file).path))
        }
        XCTAssertEqual(try Data(contentsOf: personalFile), Data("personal".utf8))
    }

    private func loadConfiguration(ready: Bool?) throws -> AppConfiguration {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Configuration-\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var values: [String: Any] = [
            "firebaseAPIKey": "fixture-key",
            "firebaseDatabaseURL": "https://fixture-default-rtdb.firebaseio.com/"
        ]
        if let ready { values["firebaseBackendReady"] = ready }
        let data = try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0)
        try data.write(to: directory.appendingPathComponent("AppConfig.plist"))
        let bundle = try XCTUnwrap(Bundle(path: directory.path))
        return AppConfiguration.load(bundle: bundle)
    }
}
