import Foundation
import MapKit
import SarjBulCore

@MainActor
final class AppState: ObservableObject {
    enum Tab: Hashable {
        case home
        case routes
        case lounge
        case account
    }

    @Published var tab: Tab = .home
    @Published var stations: [Station] = []
    @Published var candidates: [StationCandidate] = []
    @Published var profile = DrivingProfile()
    @Published var filters = StationFilters()
    @Published var userLocation: UserLocation?
    @Published var loadingMessage: String?
    @Published var errorMessage: String?

    private let repository: any StationRepository
    private let searchEngine = StationSearchEngine()

    init(repository: any StationRepository) {
        self.repository = repository
    }

    static func bootstrap() -> AppState {
        if let url = Bundle.main.url(forResource: "stations", withExtension: "json") {
            return AppState(repository: LocalStationRepository(fileURL: url))
        }
        return AppState(repository: EmptyStationRepository())
    }

    func load() {
        guard stations.isEmpty else { return }
        loadingMessage = "İstasyonlar hazırlanıyor"
        Task {
            do {
                stations = try await repository.loadStations()
                loadingMessage = nil
            } catch {
                loadingMessage = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    func updateLocation(latitude: Double, longitude: Double, source: UserLocation.Source) {
        userLocation = UserLocation(latitude: latitude, longitude: longitude, source: source)
        candidates = []
    }

    func findStations() {
        guard let userLocation else {
            errorMessage = "Rota için konum seçmelisin."
            return
        }
        loadingMessage = "En iyi duraklar hesaplanıyor"
        candidates = searchEngine.candidates(
            from: stations,
            origin: userLocation,
            profile: profile,
            filters: filters,
            limit: 80
        )
        loadingMessage = nil
        tab = .routes
    }
}

private struct EmptyStationRepository: StationRepository {
    func loadStations() async throws -> [Station] {
        throw StationRepositoryError.missingResource
    }
}
