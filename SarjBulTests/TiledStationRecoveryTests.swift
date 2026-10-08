import CryptoKit
import Foundation
import Testing
@testable import SarjBulCore

@Suite(.serialized)
struct TiledStationRecoveryTests {
    @Test(arguments: [false, true])
    func failedRefreshKeepsLastCommittedDataset(corruptResponse: Bool) async throws {
        let fixture = try TileFixture()
        defer { fixture.remove() }
        let current = try fixture.writeVersion("cached", to: fixture.cache)
        let next = try fixture.version("next")
        TileHTTPStub.responses.set([
            "/manifest": next.manifest,
            "/station_tile_a.json": next.first,
            "/station_tile_b.json": corruptResponse ? Data("invalid".utf8) : nil
        ].compactMapValues { $0 })
        let repository = fixture.repository()
        #expect(try await repository.loadStations().first?.name == "cached")
        await #expect(throws: (any Error).self) { try await repository.refreshStations() }
        #expect(try Data(contentsOf: fixture.cache.appending(path: "station-tiles-manifest.json")) == current.manifest)
        #expect(try await repository.loadStations().first?.name == "cached")
        #expect(try await fixture.repository().loadStations().first?.name == "cached")
    }

    @Test
    func successfulRefreshCommitsAndRestoresAfterRelaunch() async throws {
        let fixture = try TileFixture()
        defer { fixture.remove() }
        _ = try fixture.writeVersion("cached", to: fixture.cache)
        let next = try fixture.version("next")
        TileHTTPStub.responses.set([
            "/manifest": next.manifest,
            "/station_tile_a.json": next.first,
            "/station_tile_b.json": next.second
        ])
        #expect(try await fixture.repository().refreshStations()?.count == 1_000)
        let restored = try await fixture.repository().loadStations()
        #expect(restored.count == 1_000)
        #expect(restored.allSatisfy { $0.name == "next" })
    }

    @Test
    func epdkPolicyDiscardsLegacyCacheAndLoadsCleanBundleOffline() async throws {
        let fixture = try TileFixture()
        defer { fixture.remove() }
        _ = try fixture.writeVersion("epdk bundle", to: fixture.bundle, epdkOnly: true)
        _ = try fixture.writeVersion("mixed cache", to: fixture.cache)
        let repository = fixture.repository(sourcePolicy: .epdkOnly)
        let stations = try await repository.loadStations()
        #expect(stations.count == 1_000)
        #expect(stations.allSatisfy { $0.source == "epdk" && $0.name == "epdk bundle" })
        #expect(!FileManager.default.fileExists(atPath: fixture.cache.appending(path: "station-tiles-manifest.json").path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.cache.path).isEmpty)
    }

    @Test
    func epdkPolicyRejectsLegacyRemoteManifestBeforeDownloadingTiles() async throws {
        let fixture = try TileFixture()
        defer { fixture.remove() }
        _ = try fixture.writeVersion("epdk bundle", to: fixture.bundle, epdkOnly: true)
        let remote = try fixture.version("mixed")
        TileHTTPStub.responses.set(["/manifest": remote.manifest])
        let repository = fixture.repository(sourcePolicy: .epdkOnly)
        await #expect(throws: (any Error).self) { try await repository.refreshStations() }
        #expect(try await repository.loadStations().first?.name == "epdk bundle")
    }

    @Test
    func epdkPolicyAcceptsPureRefreshAndRejectsHiddenThirdPartyFields() async throws {
        let fixture = try TileFixture()
        defer { fixture.remove() }
        _ = try fixture.writeVersion("epdk bundle", to: fixture.bundle, epdkOnly: true)
        let remote = try fixture.version("pure remote", epdkOnly: true)
        TileHTTPStub.responses.set(["/manifest": remote.manifest,
                                   "/station_tile_a.json": remote.first, "/station_tile_b.json": remote.second])
        #expect(try await fixture.repository(sourcePolicy: .epdkOnly).refreshStations()?.count == 1_000)
        #expect(try await fixture.repository(sourcePolicy: .epdkOnly).loadStations().first?.name == "pure remote")
        let originalRows = try #require(JSONSerialization.jsonObject(with: remote.first) as? [[String: Any]])
        for change: [String: Any] in [
            ["kaynaklar": ["epdk", "osm"]], ["source_ids": ["epdk": "ŞRJ/0", "chargeiq": "old"]],
            ["id": "chargeiq_old"], ["opening_hours": "24/7"]
        ] {
            var rows = originalRows
            rows[0].merge(change) { _, new in new }
            let data = try JSONSerialization.data(withJSONObject: rows)
            #expect(throws: (any Error).self) { try StationSourcePolicy.epdkOnly.decode(data, using: JSONDecoder()) }
        }
    }

    @Test
    func malformedTilePathsAreRejectedBeforeWriting() async throws {
        let fixture = try TileFixture()
        defer { fixture.remove() }
        let next = try fixture.version("next")
        var manifest = try JSONDecoder().decode(StationTileManifest.self, from: next.manifest)
        manifest.tiles[0].file = "../station_tile_escape.json"
        TileHTTPStub.responses.set(["/manifest": try JSONEncoder().encode(manifest)])
        await #expect(throws: (any Error).self) { try await fixture.repository().refreshStations() }
        #expect(!FileManager.default.fileExists(atPath: fixture.root.appending(path: "station_tile_escape.json").path))
    }
}

private struct TileFixture {
    struct Version {
        var manifest: Data
        var first: Data
        var second: Data
    }
    let root = FileManager.default.temporaryDirectory.appending(path: "tile-tests-\(UUID().uuidString)")
    var bundle: URL { root.appending(path: "bundle") }
    var cache: URL { root.appending(path: "cache") }

    init() throws {
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        _ = try writeVersion("bundled", to: bundle)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    func version(_ name: String, epdkOnly: Bool = false) throws -> Version {
        func data(start: Int) throws -> Data {
            let encoded = try JSONEncoder().encode((start..<(start + 500)).map { index in
                Station(id: epdkOnly ? "epdk_\(index)" : "\(index)", name: name, address: "Test", latitude: 38.4, longitude: 27.1,
                        power: "50 kW", operatorName: "Test", socket: "CCS", price: "Bilinmiyor",
                        source: epdkOnly ? "epdk" : "test", sources: epdkOnly ? ["epdk"] : [])
            })
            guard epdkOnly else { return encoded }
            var rows = try #require(JSONSerialization.jsonObject(with: encoded) as? [[String: Any]])
            for index in rows.indices { rows[index]["source_ids"] = ["epdk": "ŞRJ/\(start + index)"] }
            return try JSONSerialization.data(withJSONObject: rows)

        }
        let first = try data(start: 0)
        let second = try data(start: 500)
        let manifest = StationTileManifest(schemaVersion: 1, generatedAt: "2026-09-05", totalRecords: 1_000,
                                           baseURL: "https://test.invalid/", tiles: [
            .init(geohash: "a", file: "station_tile_a.json", recordCount: 500, sha256: hash(first)),
            .init(geohash: "b", file: "station_tile_b.json", recordCount: 500, sha256: hash(second))
        ], sourcePolicy: epdkOnly ? "epdk-only-v1" : nil)
        return Version(manifest: try JSONEncoder().encode(manifest), first: first, second: second)
    }

    func writeVersion(_ name: String, to directory: URL, epdkOnly: Bool = false) throws -> Version {
        let value = try version(name, epdkOnly: epdkOnly)
        try value.manifest.write(to: directory.appending(path: "station-tiles-manifest.json"))
        try value.first.write(to: directory.appending(path: "station_tile_a.json"))
        try value.second.write(to: directory.appending(path: "station_tile_b.json"))
        return value
    }

    func repository(sourcePolicy: StationSourcePolicy = .unrestricted) -> TiledStationRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TileHTTPStub.self]
        return TiledStationRepository(bundledManifestURL: bundle.appending(path: "station-tiles-manifest.json"),
                                      remoteManifestURL: URL(string: "https://test.invalid/manifest"),
                                      cacheDirectory: cache, session: URLSession(configuration: configuration), sourcePolicy: sourcePolicy)
    }

    private func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private final class TileResponses: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func set(_ values: [String: Data]) {
        lock.lock()
        defer { lock.unlock() }
        self.values = values
    }
    func get(_ path: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[path]
    }
}

private final class TileHTTPStub: URLProtocol, @unchecked Sendable {
    static let responses = TileResponses()
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, let data = Self.responses.get(url.path),
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
