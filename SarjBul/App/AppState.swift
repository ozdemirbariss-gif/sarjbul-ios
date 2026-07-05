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
    private static let authSessionDefaultsKey = "firebaseAuthSession"

    var tab: Tab = .account
    private(set) var stations: [Station] = []
    private(set) var stationStatuses: [String: StationStatusSummary] = [:]
    var profile = DrivingProfile() {
        didSet { persistProfile() }
    }
    var filters = StationFilters()
    var userLocation: UserLocation?
    var search: SearchState = .idle
    var authSession: FirebaseAuthSession? {
        didSet { persistAuthSession() }
    }
    private(set) var favorites: Set<String> = []
    var loadingMessage: String?
    var errorMessage: String?
    var successMessage: String?
    private var pendingFavoriteKeys: Set<String> = []

    private let repository: any StationRepository
    private let firebaseClient: FirebaseRESTClient?
    private let searchEngine = StationSearchEngine()

    init(
        repository: any StationRepository,
        firebaseClient: FirebaseRESTClient? = nil,
        profile: DrivingProfile = DrivingProfile(),
        authSession: FirebaseAuthSession? = nil
    ) {
        self.repository = repository
        self.firebaseClient = firebaseClient
        self.profile = profile
        self.authSession = authSession
    }

    static func bootstrap() -> AppState {
        let restoredProfile = restoreProfile()
        let restoredSession = restoreAuthSession()
        let config = AppConfiguration.load()
        if let url = Bundle.main.url(forResource: "stations", withExtension: "json") {
            return AppState(
                repository: LocalStationRepository(fileURL: url),
                firebaseClient: config.firebaseClient,
                profile: restoredProfile,
                authSession: restoredSession
            )
        }
        return AppState(
            repository: EmptyStationRepository(),
            firebaseClient: config.firebaseClient,
            profile: restoredProfile,
            authSession: restoredSession
        )
    }

    func load() async {
        guard stations.isEmpty else { return }
        loadingMessage = "İstasyonlar hazırlanıyor"
        errorMessage = nil
        let repository = repository

        do {
            stations = try await Task.detached(priority: .utility) {
                try await repository.loadStations()
            }.value
            loadingMessage = nil
            await loadStationStatuses()
            if authSession != nil {
                await loadFavorites()
            }
        } catch {
            loadingMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    func retryLoad() async {
        await load()
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
        let stationStatuses = stationStatuses
        let searchEngine = searchEngine

        let result = await Task.detached(priority: .userInitiated) {
            searchEngine.candidates(
                from: stations,
                origin: userLocation,
                profile: profile,
                filters: filters,
                stationStatuses: stationStatuses,
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
        userLocation != nil && !stations.isEmpty && !isSearching
    }

    var message: String? {
        if case .failed(let message) = search { return message }
        return errorMessage ?? successMessage
    }

    var messageTitle: String {
        successMessage == nil ? "İşlem tamamlanamadı" : "Tamamlandı"
    }

    var stationLoadChipText: String {
        if let loadingMessage { return loadingMessage }
        return stations.isEmpty ? "İstasyonlar hazırlanıyor" : "\(stations.count) istasyon hazır"
    }

    var canRetryStationLoad: Bool {
        stations.isEmpty && loadingMessage == nil && errorMessage != nil
    }

    var isFirebaseConfigured: Bool {
        firebaseClient != nil
    }

    var isAuthenticated: Bool {
        authSession?.uid.isEmpty == false
    }

    func dismissMessage() {
        errorMessage = nil
        successMessage = nil
        if case .failed = search {
            search = .idle
        }
    }

    func applyFilters(_ filters: StationFilters) async {
        self.filters = filters
        guard userLocation != nil else { return }
        await findStations()
    }

    func signIn(email: String, password: String) async {
        guard let firebaseClient else {
            errorMessage = "Firebase ayarları AppConfig.plist içinde tanımlı değil."
            return
        }

        do {
            authSession = try await firebaseClient.signIn(email: email, password: password)
            await loadFavorites()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        guard let firebaseClient else {
            errorMessage = "Firebase ayarları AppConfig.plist içinde tanımlı değil."
            return
        }

        do {
            authSession = try await firebaseClient.signUp(email: email, password: password)
            await loadFavorites()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetPassword(email: String) async {
        guard let firebaseClient else {
            errorMessage = "Firebase ayarları AppConfig.plist içinde tanımlı değil."
            return
        }

        do {
            try await firebaseClient.sendPasswordReset(email: email)
            successMessage = "Şifre sıfırlama bağlantısı gönderildi."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        authSession = nil
        favorites = []
        stationStatuses = [:]
    }

    func isFavorite(_ stationKey: String) -> Bool {
        favorites.contains(stationKey)
    }

    func toggleFavorite(_ stationKey: String) async {
        guard let firebaseClient else {
            errorMessage = "Kaydetmek için giriş yapmalısın."
            return
        }
        guard !pendingFavoriteKeys.contains(stationKey) else { return }

        pendingFavoriteKeys.insert(stationKey)
        defer { pendingFavoriteKeys.remove(stationKey) }
        let shouldFavorite = !favorites.contains(stationKey)
        if shouldFavorite {
            favorites.insert(stationKey)
        } else {
            favorites.remove(stationKey)
        }

        do {
            try await authenticatedRequest { session in
                try await firebaseClient.setFavorite(
                    uid: session.uid,
                    stationKey: stationKey,
                    isFavorite: shouldFavorite,
                    idToken: session.idToken
                )
            }
        } catch {
            if shouldFavorite {
                favorites.remove(stationKey)
            } else {
                favorites.insert(stationKey)
            }
            errorMessage = error.localizedDescription
        }
    }

    func reportStatus(stationKey: String, status: String) async {
        guard let firebaseClient else {
            errorMessage = "Durum bildirmek için giriş yapmalısın."
            return
        }

        do {
            try await authenticatedRequest { session in
                try await firebaseClient.sendStationReport(
                    stationKey: stationKey,
                    status: status,
                    comment: status,
                    uid: session.uid,
                    idToken: session.idToken
                )
            }
            await loadStationStatuses()
            await findStations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadStationStatuses() async {
        guard let firebaseClient else { return }
        do {
            if authSession != nil {
                stationStatuses = try await authenticatedRequest { session in
                    try await firebaseClient.stationStatuses(idToken: session.idToken)
                }
            } else {
                stationStatuses = try await firebaseClient.stationStatuses()
            }
        } catch {
            stationStatuses = [:]
        }
    }

    private func loadFavorites() async {
        guard let firebaseClient, authSession != nil else { return }
        do {
            favorites = try await authenticatedRequest { session in
                try await firebaseClient.favoriteIDs(uid: session.uid, idToken: session.idToken)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func authenticatedRequest<T>(_ operation: (FirebaseAuthSession) async throws -> T) async throws -> T {
        do {
            return try await operation(try await validToken())
        } catch let error as FirebaseRESTError where error.isUnauthorized {
            return try await operation(try await forceRefreshToken())
        }
    }

    private func validToken() async throws -> FirebaseAuthSession {
        guard authSession != nil else {
            throw FirebaseRESTError.requestFailed("Oturum yok.")
        }
        if authSession?.isExpired == true {
            return try await forceRefreshToken()
        }
        return authSession!
    }

    private func forceRefreshToken() async throws -> FirebaseAuthSession {
        guard let firebaseClient else {
            throw FirebaseRESTError.requestFailed("Firebase ayarları AppConfig.plist içinde tanımlı değil.")
        }
        guard let current = authSession else {
            throw FirebaseRESTError.requestFailed("Oturum yok.")
        }

        var refreshed = try await firebaseClient.refreshSession(refreshToken: current.refreshToken)
        if refreshed.email == nil {
            refreshed.email = current.email
        }
        if refreshed.localId == nil {
            refreshed.localId = current.localId
        }
        if refreshed.userId == nil {
            refreshed.userId = current.userId
        }
        authSession = refreshed
        return refreshed
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

    private static func restoreAuthSession() -> FirebaseAuthSession? {
        if
            let data = KeychainStore.data(for: authSessionDefaultsKey),
            let session = try? JSONDecoder().decode(FirebaseAuthSession.self, from: data) {
            return session
        }

        if
            let data = UserDefaults.standard.data(forKey: authSessionDefaultsKey),
            let session = try? JSONDecoder().decode(FirebaseAuthSession.self, from: data) {
            KeychainStore.set(data, for: authSessionDefaultsKey)
            UserDefaults.standard.removeObject(forKey: authSessionDefaultsKey)
            return session
        }

        return nil
    }

    private func persistProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.profileDefaultsKey)
        }
    }

    private func persistAuthSession() {
        guard let authSession else {
            KeychainStore.remove(Self.authSessionDefaultsKey)
            UserDefaults.standard.removeObject(forKey: Self.authSessionDefaultsKey)
            return
        }

        if let data = try? JSONEncoder().encode(authSession) {
            KeychainStore.set(data, for: Self.authSessionDefaultsKey)
            UserDefaults.standard.removeObject(forKey: Self.authSessionDefaultsKey)
        }
    }
}

private struct EmptyStationRepository: StationRepository {
    func loadStations() async throws -> [Station] {
        throw StationRepositoryError.missingResource
    }
}
