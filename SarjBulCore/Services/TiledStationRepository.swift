import CryptoKit
import Foundation

public struct StationTileManifest: Codable, Equatable, Sendable {
    public struct Tile: Codable, Equatable, Sendable {
        public var geohash: String
        public var file: String
        public var recordCount: Int
        public var sha256: String

        public init(geohash: String, file: String, recordCount: Int, sha256: String) {
            self.geohash = geohash
            self.file = file
            self.recordCount = recordCount
            self.sha256 = sha256
        }

        private enum CodingKeys: String, CodingKey {
            case geohash
            case file
            case recordCount = "record_count"
            case sha256
        }
    }

    public var schemaVersion: Int
    public var generatedAt: String
    public var totalRecords: Int
    public var baseURL: String
    public var tiles: [Tile]

    public init(
        schemaVersion: Int,
        generatedAt: String,
        totalRecords: Int,
        baseURL: String,
        tiles: [Tile]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.totalRecords = totalRecords
        self.baseURL = baseURL
        self.tiles = tiles
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
        case totalRecords = "total_records"
        case baseURL = "base_url"
        case tiles
    }
}

public actor TiledStationRepository: RefreshableStationRepository {
    private let bundledManifestURL: URL
    private let remoteManifestURL: URL?
    private let cacheDirectory: URL
    private let session: URLSession
    private let decoder = JSONDecoder()

    public init(
        bundledManifestURL: URL,
        remoteManifestURL: URL?,
        cacheDirectory: URL,
        session: URLSession = .shared
    ) {
        self.bundledManifestURL = bundledManifestURL
        self.remoteManifestURL = remoteManifestURL
        self.cacheDirectory = cacheDirectory
        self.session = session
    }

    public func loadStations() async throws -> [Station] {
        if let cached = try? cachedManifest(),
           let stations = try? decodeStations(manifest: cached) {
            return stations
        }
        return try decodeStations(manifest: bundledManifest())
    }

    public func refreshStations() async throws -> [Station]? {
        guard let remoteManifestURL else { return nil }
        var request = URLRequest(url: remoteManifestURL)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadRevalidatingCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SarjBul-iOS/1", forHTTPHeaderField: "User-Agent")
        if let metadata = try? metadata(), let etag = metadata.etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (manifestData, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw StationRepositoryError.invalidRemoteData }
        if response.statusCode == 304 { return nil }
        guard (200..<300).contains(response.statusCode) else { throw URLError(.badServerResponse) }

        let remoteManifest = try decoder.decode(StationTileManifest.self, from: manifestData)
        let bundled = try bundledManifest()
        let minimumAcceptedCount = StationDatasetQualityGate.minimumAcceptedCount(
            referenceCount: bundled.totalRecords
        )
        guard remoteManifest.schemaVersion == 1,
              remoteManifest.totalRecords >= minimumAcceptedCount,
              !remoteManifest.tiles.isEmpty else {
            throw StationRepositoryError.invalidRemoteData
        }

        let bundledTiles = Dictionary(uniqueKeysWithValues: bundled.tiles.map { ($0.file, $0) })
        let cachedTiles = (try? cachedManifest()).map {
            Dictionary(uniqueKeysWithValues: $0.tiles.map { ($0.file, $0) })
        } ?? [:]
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        for tile in remoteManifest.tiles {
            if cachedTiles[tile.file]?.sha256 == tile.sha256,
               FileManager.default.fileExists(atPath: cacheDirectory.appending(path: tile.file).path) {
                continue
            }
            if bundledTiles[tile.file]?.sha256 == tile.sha256 { continue }
            try await download(tile: tile, manifest: remoteManifest)
        }

        let stations = try decodeStations(manifest: remoteManifest)
        guard stations.count >= minimumAcceptedCount else { throw StationRepositoryError.invalidRemoteData }
        try manifestData.write(to: cacheDirectory.appending(path: "station-tiles-manifest.json"), options: .atomic)
        try JSONEncoder().encode(RemoteTileMetadata(
            etag: response.value(forHTTPHeaderField: "ETag"),
            updatedAt: Date()
        )).write(to: cacheDirectory.appending(path: "station-tiles-metadata.json"), options: .atomic)
        removeStaleTiles(keeping: Set(remoteManifest.tiles.map(\.file)))
        return stations
    }

    private func download(tile: StationTileManifest.Tile, manifest: StationTileManifest) async throws {
        guard let baseURL = URL(string: manifest.baseURL),
              let url = URL(string: tile.file, relativeTo: baseURL)?.absoluteURL else {
            throw StationRepositoryError.invalidRemoteData
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
              sha256(data) == tile.sha256 else {
            throw StationRepositoryError.invalidRemoteData
        }
        try data.write(to: cacheDirectory.appending(path: tile.file), options: .atomic)
    }

    private func decodeStations(manifest: StationTileManifest) throws -> [Station] {
        var stations: [Station] = []
        stations.reserveCapacity(manifest.totalRecords)
        let bundled = try bundledManifest()
        let bundledByFile = Dictionary(uniqueKeysWithValues: bundled.tiles.map { ($0.file, $0) })
        for tile in manifest.tiles {
            let cacheURL = cacheDirectory.appending(path: tile.file)
            let data: Data
            if FileManager.default.fileExists(atPath: cacheURL.path) {
                let cached = try Data(contentsOf: cacheURL)
                if sha256(cached) == tile.sha256 {
                    data = cached
                } else if bundledByFile[tile.file]?.sha256 == tile.sha256 {
                    data = try bundledTileData(tile.file)
                } else {
                    throw StationRepositoryError.invalidRemoteData
                }
            } else if bundledByFile[tile.file]?.sha256 == tile.sha256 {
                data = try bundledTileData(tile.file)
            } else {
                throw StationRepositoryError.invalidRemoteData
            }
            let decoded = try decoder.decode([Station].self, from: data)
            guard decoded.count == tile.recordCount else {
                throw StationRepositoryError.invalidRemoteData
            }
            stations.append(contentsOf: decoded)
        }
        guard !stations.isEmpty, stations.count == manifest.totalRecords else {
            throw StationRepositoryError.invalidRemoteData
        }
        return stations
    }

    private func bundledTileData(_ file: String) throws -> Data {
        let siblingURL = bundledManifestURL.deletingLastPathComponent().appending(path: file)
        if FileManager.default.fileExists(atPath: siblingURL.path) {
            return try Data(contentsOf: siblingURL)
        }
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw StationRepositoryError.missingResource
        }
        return try Data(contentsOf: url)
    }

    private func bundledManifest() throws -> StationTileManifest {
        try decoder.decode(StationTileManifest.self, from: Data(contentsOf: bundledManifestURL))
    }

    private func cachedManifest() throws -> StationTileManifest {
        let url = cacheDirectory.appending(path: "station-tiles-manifest.json")
        return try decoder.decode(StationTileManifest.self, from: Data(contentsOf: url))
    }

    private func metadata() throws -> RemoteTileMetadata {
        let data = try Data(contentsOf: cacheDirectory.appending(path: "station-tiles-metadata.json"))
        return try decoder.decode(RemoteTileMetadata.self, from: data)
    }

    private func removeStaleTiles(keeping filenames: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path) else { return }
        for file in files where file.hasPrefix("station_tile_") && !filenames.contains(file) {
            try? FileManager.default.removeItem(at: cacheDirectory.appending(path: file))
        }
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct RemoteTileMetadata: Codable {
    var etag: String?
    var updatedAt: Date
}
