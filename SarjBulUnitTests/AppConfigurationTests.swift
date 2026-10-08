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
