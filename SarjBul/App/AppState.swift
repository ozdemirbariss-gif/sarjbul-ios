import Foundation
import Observation
import SarjBulCore
import SwiftUI

@MainActor
@Observable
final class AppState {
    enum Tab: Hashable {
        case home
        case routes
        case lounge
        case account
    }

    enum SearchState {
        case idle
        case searching
        case results([StationCandidate])
        case failed(String)

        var isSearching: Bool {
            if case .searching = self { return true }
            return false
        }

        var candidates: [StationCandidate] {
            if case .results(let candidates) = self { return candidates }
            return []
        }
    }

    private static let profileDefaultsKey = "drivingProfile"

    var tab: Tab = .home
    private(set) var stations: [Station] = []
    var profile = DrivingProfile() {
        didSet { persistProfile() }
    }
    var filters = StationFilters()
    var userLocation: UserLocation?
    var search: SearchState = .idle
    var loadingMessage: String?
    var errorMessage: String?

    private let repository: any StationRepository
    private let searchEngine = StationSearchEngine()

    init(repository: any StationRepository, profile: DrivingProfile = DrivingProfile()) {
        self.repository = repository
        self.profile = profile
    }

    static func bootstrap() -> AppState {
        let restoredProfile = restoreProfile()
        if let url = Bundle.main.url(forResource: "stations", withExtension: "json") {
            return AppState(repository: LocalStationRepository(fileURL: url), profile: restoredProfile)
        }
        return AppState(repository: EmptyStationRepository(), profile: restoredProfile)
    }

    func load() async {
        guard stations.isEmpty else { return }
        loadingMessage = "İstasyonlar hazırlanıyor"
        let repository = repository

        do {
            stations = try await Task.detached(priority: .utility) {
                try await repository.loadStations()
            }.value
            loadingMessage = nil
        } catch {
            loadingMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    func updateLocation(latitude: Double, longitude: Double, source: UserLocation.Source) {
        userLocation = UserLocation(latitude: latitude, longitude: longitude, source: source)
        search = .idle
    }

    func findStations() async {
        guard let userLocation else {
            search = .failed("Rota için konum seçmelisin.")
            return
        }

        search = .searching
        let stations = stations
        let profile = profile
        let filters = filters
        let searchEngine = searchEngine

        let result = await Task.detached(priority: .userInitiated) {
            searchEngine.candidates(
                from: stations,
                origin: userLocation,
                profile: profile,
                filters: filters,
                limit: 80
            )
        }.value

        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            search = .results(result)
            tab = .routes
        }
    }

    var routeCandidates: [StationCandidate] {
        search.candidates
    }

    var isSearching: Bool {
        search.isSearching
    }

    var canSearch: Bool {
        !stations.isEmpty && !isSearching
    }

    var message: String? {
        if case .failed(let message) = search { return message }
        return errorMessage
    }

    var stationLoadChipText: String {
        if let loadingMessage { return loadingMessage }
        return stations.isEmpty ? "İstasyonlar hazırlanıyor" : "\(stations.count) istasyon hazır"
    }

    func dismissMessage() {
        errorMessage = nil
        if case .failed = search {
            search = .idle
        }
    }

    func applyFilters(_ filters: StationFilters) async {
        self.filters = filters
        guard userLocation != nil else { return }
        await findStations()
    }

    private static func restoreProfile() -> DrivingProfile {
        guard
            let data = UserDefaults.standard.data(forKey: profileDefaultsKey),
            let profile = try? JSONDecoder().decode(DrivingProfile.self, from: data)
        else {
            return DrivingProfile()
        }
        return profile
    }

    private func persistProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.profileDefaultsKey)
        }
    }
}

private struct EmptyStationRepository: StationRepository {
    func loadStations() async throws -> [Station] {
        throw StationRepositoryError.missingResource
    }
}
