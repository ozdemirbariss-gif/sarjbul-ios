import Foundation

public protocol StationRepository: Sendable {
    func loadStations() async throws -> [Station]
}

public protocol RefreshableStationRepository: StationRepository {
    func refreshStations() async throws -> [Station]?
}

public enum StationRepositoryError: Error, LocalizedError {
    case missingResource
    case emptyData
    case invalidRemoteData

    public var errorDescription: String? {
        switch self {
        case .missingResource: "İstasyon verisi bulunamadı."
        case .emptyData: "İstasyon verisi boş."
        case .invalidRemoteData: "Uzak istasyon verisi kalite kontrolünü geçemedi."
        }
    }
}
