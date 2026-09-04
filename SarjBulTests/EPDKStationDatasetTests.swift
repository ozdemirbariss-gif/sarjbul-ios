import CryptoKit
import Foundation
import Testing
@testable import SarjBulCore

@Suite
struct EPDKStationDatasetTests {
    @Test
    func publishedInventoryDecodesAndProducesSearchResults() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appending(path: "SarjBul/Resources/StationTiles")
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(
            StationTileManifest.self,
            from: Data(contentsOf: directory.appending(path: "station-tiles-manifest.json"))
        )
        var stations: [Station] = []
        for tile in manifest.tiles {
            let data = try Data(contentsOf: directory.appending(path: tile.file))
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            #expect(digest == tile.sha256)
            let decoded = try decoder.decode([Station].self, from: data)
            #expect(decoded.count == tile.recordCount)
            stations.append(contentsOf: decoded)
        }
        #expect(stations.count == manifest.totalRecords)
        #expect(Set(stations.map(\.id)).count == stations.count)
        let official = stations.filter { $0.source == "epdk" }
        #expect(official.count >= 1_000)
        #expect(official.allSatisfy { $0.hasValidCoordinate })
        let sample = try #require(official.first { $0.powerKW >= 50 })
        let results = StationSearchEngine().candidates(
            from: stations,
            origin: UserLocation(latitude: sample.latitude, longitude: sample.longitude, source: .manual),
            profile: DrivingProfile(chargePercent: 80),
            filters: StationFilters(preference: .nearest)
        )
        #expect(!results.isEmpty)
        #expect(results.contains { $0.station.id == sample.id })
    }
}
