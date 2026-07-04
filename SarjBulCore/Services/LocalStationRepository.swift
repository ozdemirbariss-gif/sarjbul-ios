import Foundation

public struct LocalStationRepository: StationRepository {
    private let fileURL: URL
    private let decoder: JSONDecoder

    public init(fileURL: URL, decoder: JSONDecoder = JSONDecoder()) {
        self.fileURL = fileURL
        self.decoder = decoder
    }

    public func loadStations() async throws -> [Station] {
        let data = try Data(contentsOf: fileURL)
        let stations = try decoder.decode([Station].self, from: data)
        if stations.isEmpty {
            throw StationRepositoryError.emptyData
        }
        return stations
    }
}

