import Foundation

public actor CachedRemoteStationRepository: RefreshableStationRepository {
    private let bundledFileURL: URL
    private let remoteURL: URL?
    private let cacheFileURL: URL
    private let metadataFileURL: URL
    private let decoder = JSONDecoder()
    private let session: URLSession

    public init(
        bundledFileURL: URL,
        remoteURL: URL?,
        cacheDirectory: URL,
        session: URLSession = .shared
    ) {
        self.bundledFileURL = bundledFileURL
        self.remoteURL = remoteURL
        cacheFileURL = cacheDirectory.appending(path: "stations.json")
        metadataFileURL = cacheDirectory.appending(path: "stations-metadata.json")
        self.session = session
    }

    public func loadStations() async throws -> [Station] {
        if let cached = try? decodeStations(at: cacheFileURL), !cached.isEmpty {
            return cached
        }
        return try decodeStations(at: bundledFileURL)
    }

    public func refreshStations() async throws -> [Station]? {
        guard let remoteURL else { return nil }

        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadRevalidatingCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SarjBul-iOS/1", forHTTPHeaderField: "User-Agent")

        if let metadata = try? loadMetadata(), let etag = metadata.etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StationRepositoryError.invalidRemoteData
        }
        if httpResponse.statusCode == 304 { return nil }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let remoteStations = try decoder.decode([Station].self, from: data)
        let bundledCount = (try? decodeStations(at: bundledFileURL).count) ?? 1_000
        guard StationDatasetQualityGate.accepts(
            candidateCount: remoteStations.count,
            referenceCount: bundledCount
        ) else {
            throw StationRepositoryError.invalidRemoteData
        }

        try FileManager.default.createDirectory(
            at: cacheFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: cacheFileURL, options: .atomic)
        try saveMetadata(RemoteMetadata(
            etag: httpResponse.value(forHTTPHeaderField: "ETag"),
            updatedAt: Date()
        ))
        return remoteStations
    }

    private func decodeStations(at url: URL) throws -> [Station] {
        let data = try Data(contentsOf: url)
        let stations = try decoder.decode([Station].self, from: data)
        guard !stations.isEmpty else { throw StationRepositoryError.emptyData }
        return stations
    }

    private func loadMetadata() throws -> RemoteMetadata {
        let data = try Data(contentsOf: metadataFileURL)
        return try decoder.decode(RemoteMetadata.self, from: data)
    }

    private func saveMetadata(_ metadata: RemoteMetadata) throws {
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataFileURL, options: .atomic)
    }
}

private struct RemoteMetadata: Codable {
    var etag: String?
    var updatedAt: Date
}
