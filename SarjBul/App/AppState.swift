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
    private static let languageDefaultsKey = "appLanguage"
    private static let destinationDefaultsKey = "journeyDestination"
    private static let recentRoutesDefaultsKey = "recentStationRoutes"
    private static let reportCooldownsDefaultsKey = "stationReportCooldowns"
    private static let reportCooldown: TimeInterval = 60

    var tab: Tab = .account
    private(set) var stations: [Station] = []
    private(set) var stationStatuses: [String: StationStatusSummary] = [:]
    var language: AppLanguage = .tr {
        didSet { persistLanguage() }
    }
    var profile = DrivingProfile() {
        didSet { persistProfile() }
    }
    var filters = StationFilters()
    var userLocation: UserLocation?
    var destination: JourneyDestination? {
        didSet {
            persistDestination()
            search = .idle
        }
    }
    var search: SearchState = .idle
    var authSession: FirebaseAuthSession? {
        didSet { persistAuthSession() }
    }
    private(set) var favorites: Set<String> = []
    private(set) var recentRoutes = AppState.restoreRecentRoutes()
    let externalLinks: AppExternalLinks
    var loadingMessage: String?
    var errorMessage: String?
    var successMessage: String?
    private var pendingFavoriteKeys: Set<String> = []
    private var reportCooldowns = AppState.restoreReportCooldowns()
    private var pendingStationKey: String?

    private let repository: any StationRepository
    private let firebaseClient: FirebaseRESTClient?
    private let searchEngine = StationSearchEngine()
    private let journeyRouteService = JourneyRouteService()

    init(
        repository: any StationRepository,
        firebaseClient: FirebaseRESTClient? = nil,
        profile: DrivingProfile = DrivingProfile(),
        authSession: FirebaseAuthSession? = nil,
        language: AppLanguage = .tr,
        externalLinks: AppExternalLinks = .empty,
        destination: JourneyDestination? = nil
    ) {
        self.repository = repository
        self.firebaseClient = firebaseClient
        self.profile = profile
        self.authSession = authSession
        self.language = language
        self.externalLinks = externalLinks
        self.destination = destination
    }

    static func bootstrap() -> AppState {
        let restoredProfile = restoreProfile()
        let restoredSession = restoreAuthSession()
        let restoredLanguage = restoreLanguage()
        let restoredDestination = restoreDestination()
        let config = AppConfiguration.load()
        let links = AppExternalLinks(
            privacyPolicyURL: config.privacyPolicyURL,
            termsOfUseURL: config.termsOfUseURL,
            supportURL: config.supportURL,
            supportEmail: config.supportEmail
        )
        let state: AppState
        if let repository = config.stationRepository() {
            state = AppState(
                repository: repository,
                firebaseClient: config.firebaseClient,
                profile: restoredProfile,
                authSession: restoredSession,
                language: restoredLanguage,
                externalLinks: links,
                destination: restoredDestination
            )
        } else {
            state = AppState(
                repository: EmptyStationRepository(),
                firebaseClient: config.firebaseClient,
                profile: restoredProfile,
                authSession: restoredSession,
                language: restoredLanguage,
                externalLinks: links,
                destination: restoredDestination
            )
        }
        state.applyDebugLaunchMode()
        return state
    }

    func t(_ key: String, _ replacements: [String: String] = [:]) -> String {
        AppLocalization.text(key, language: language, replacements: replacements)
    }

    func setLanguage(code: String) {
        language = AppLanguage(code: code)
    }

    func load() async {
        guard stations.isEmpty else { return }
        loadingMessage = t("data.loading")
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
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing-routes") {
                await findStations()
            }
            #endif
            await refreshStationDataIfAvailable()
        } catch {
            loadingMessage = nil
            errorMessage = error.localizedDescription
            AppLogger.data.error("Station load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func retryLoad() async {
        await load()
    }

    func updateLocation(latitude: Double, longitude: Double, source: UserLocation.Source) {
        userLocation = UserLocation(latitude: latitude, longitude: longitude, source: source)
        search = .idle
        if let pendingStationKey {
            self.pendingStationKey = nil
            Task { await openStation(withKey: pendingStationKey) }
        }
    }

    func findStations() async {
        guard let userLocation else {
            search = .failed(t("route.location_required"))
            return
        }

        search = .searching
        let stations = stations
        let profile = profile
        let filters = filters
        let stationStatuses = stationStatuses
        let destination = destination
        let searchEngine = searchEngine
        let routePoints: [UserLocation]
        if let destination {
            do {
                routePoints = try await journeyRouteService.corridorPoints(
                    origin: userLocation,
                    destination: destination
                )
            } catch {
                routePoints = []
                AppLogger.routing.warning("Journey corridor route failed: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            routePoints = []
        }

        let result = await Task.detached(priority: .userInitiated) {
            if let destination {
                searchEngine.candidatesAlongJourney(
                    from: stations,
                    origin: userLocation,
                    destination: destination,
                    routePoints: routePoints,
                    profile: profile,
                    filters: filters,
                    stationStatuses: stationStatuses,
                    limit: 80
                )
            } else {
                searchEngine.candidates(
                    from: stations,
                    origin: userLocation,
                    profile: profile,
                    filters: filters,
                    stationStatuses: stationStatuses,
                    limit: 80
                )
            }
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
        successMessage == nil ? t("status.error") : t("status.ok")
    }

    var stationLoadChipText: String {
        if let loadingMessage { return loadingMessage }
        return stations.isEmpty
            ? t("data.loading")
            : t("data.ready", ["count": "\(stations.count)"])
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

    func consumeErrorMessage() -> String? {
        defer { errorMessage = nil }
        return errorMessage
    }

    func applyFilters(_ filters: StationFilters) async {
        self.filters = filters
        guard userLocation != nil else { return }
        await findStations()
    }

    func signIn(email: String, password: String) async {
        guard let firebaseClient else {
            errorMessage = t("service.firebase_missing")
            return
        }

        do {
            errorMessage = nil
            authSession = try await firebaseClient.signIn(email: email, password: password)
            await loadFavorites()
        } catch {
            setServiceError(error)
        }
    }

    func signUp(email: String, password: String) async {
        guard let firebaseClient else {
            errorMessage = t("service.firebase_missing")
            return
        }

        do {
            errorMessage = nil
            authSession = try await firebaseClient.signUp(email: email, password: password)
            var verificationSent = false
            if let idToken = authSession?.idToken {
                do {
                    try await firebaseClient.sendEmailVerification(idToken: idToken)
                    verificationSent = true
                } catch {
                    AppLogger.account.warning("Verification email failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            await loadFavorites()
            successMessage = t(verificationSent ? "service.verification_sent" : "service.verification_pending")
        } catch {
            setServiceError(error)
        }
    }

    func resetPassword(email: String) async {
        guard let firebaseClient else {
            errorMessage = t("service.firebase_missing")
            return
        }

        do {
            errorMessage = nil
            try await firebaseClient.sendPasswordReset(email: email)
            successMessage = t("service.reset_sent")
        } catch {
            setServiceError(error)
        }
    }

    func signOut() {
        authSession = nil
        favorites = []
        stationStatuses = [:]
        Task { await loadStationStatuses() }
    }

    func deleteAccount() async -> Bool {
        guard let firebaseClient else {
            errorMessage = t("service.firebase_missing")
            return false
        }

        do {
            let session = try await validToken()
            try await firebaseClient.initiateAccountDeletion(
                uid: session.uid,
                idToken: session.idToken
            )
            try await firebaseClient.deleteAccount(idToken: session.idToken)
            signOut()
            successMessage = t("service.account_deleted")
            return true
        } catch {
            AppLogger.account.error("Account deletion failed: \(error.localizedDescription, privacy: .public)")
            setServiceError(error)
            return false
        }
    }

    func isFavorite(_ stationKey: String) -> Bool {
        favorites.contains(stationKey)
    }

    func toggleFavorite(_ stationKey: String) async {
        guard let firebaseClient else {
            errorMessage = t("service.favorite_login_required")
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
            setServiceError(error)
        }
    }

    var favoriteStations: [Station] {
        stations.filter { favorites.contains($0.statusKey) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var recentStations: [Station] {
        recentRoutes.compactMap { recent in
            stations.first { $0.id == recent.stationID || $0.statusKey == recent.stationKey }
        }
    }

    func recordRouteOpened(_ station: Station) {
        recentRoutes.removeAll { $0.stationID == station.id || $0.stationKey == station.statusKey }
        recentRoutes.insert(
            RecentStationRoute(stationID: station.id, stationKey: station.statusKey, openedAt: Date()),
            at: 0
        )
        recentRoutes = Array(recentRoutes.prefix(12))
        persistRecentRoutes()
    }

    func canReportStatus(for stationKey: String, now: Date = Date()) -> Bool {
        guard let lastReport = reportCooldowns[stationKey] else { return true }
        return now.timeIntervalSince(lastReport) >= Self.reportCooldown
    }

    func reportCooldownRemaining(for stationKey: String, now: Date = Date()) -> Int {
        guard let lastReport = reportCooldowns[stationKey] else { return 0 }
        return max(0, Int(ceil(Self.reportCooldown - now.timeIntervalSince(lastReport))))
    }

    func reportStatus(stationKey: String, status: String) async {
        guard let firebaseClient else {
            errorMessage = t("service.report_login_required")
            return
        }
        guard canReportStatus(for: stationKey) else {
            errorMessage = t("service.report_cooldown", [
                "seconds": "\(reportCooldownRemaining(for: stationKey))"
            ])
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
            reportCooldowns[stationKey] = Date()
            persistReportCooldowns()
            await loadStationStatuses()
            await findStations()
            successMessage = t("service.report_sent")
        } catch {
            setServiceError(error)
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
            AppLogger.data.error("Station statuses failed: \(error.localizedDescription, privacy: .public)")
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
            AppLogger.account.error("Favorites failed: \(error.localizedDescription, privacy: .public)")
            setServiceError(error)
        }
    }

    private func refreshStationDataIfAvailable() async {
        guard let repository = repository as? any RefreshableStationRepository else { return }
        do {
            guard let refreshed = try await repository.refreshStations(), !refreshed.isEmpty else { return }
            stations = refreshed
        } catch {
            AppLogger.data.warning("Remote station refresh skipped: \(error.localizedDescription, privacy: .public)")
        }
    }

    func handleDeepLink(_ url: URL) async {
        guard url.scheme?.lowercased() == "sarjbul", url.host?.lowercased() == "station" else { return }
        guard let encodedKey = url.pathComponents.dropFirst().first,
              let key = encodedKey.removingPercentEncoding,
              !key.isEmpty else { return }
        await openStation(withKey: key)
    }

    func openStation(withKey key: String) async {
        guard let station = stations.first(where: { $0.statusKey == key || $0.id == key }) else {
            errorMessage = t("deep_link.not_found")
            return
        }
        guard let origin = userLocation else {
            pendingStationKey = key
            tab = .home
            successMessage = t("deep_link.location_needed")
            return
        }

        await findStations()
        var candidates = routeCandidates
        if let index = candidates.firstIndex(where: { $0.station.id == station.id }) {
            let candidate = candidates.remove(at: index)
            candidates.insert(candidate, at: 0)
        } else {
            var relaxedFilters = filters
            relaxedFilters.rangeFilterEnabled = false
            relaxedFilters.minimumPowerKW = 0
            relaxedFilters.socketFilters = []
            let direct = searchEngine.candidates(
                from: [station],
                origin: origin,
                profile: profile,
                filters: relaxedFilters,
                stationStatuses: stationStatuses,
                limit: 1
            )
            candidates.insert(contentsOf: direct, at: 0)
        }
        search = .results(candidates)
        tab = .routes
    }

    private func setServiceError(_ error: Error) {
        let message = error.localizedDescription.uppercased()
        if message.contains("INVALID_LOGIN_CREDENTIALS") || message.contains("INVALID_PASSWORD") {
            errorMessage = t("service.invalid_credentials")
        } else if message.contains("EMAIL_EXISTS") {
            errorMessage = t("service.email_exists")
        } else if message.contains("WEAK_PASSWORD") {
            errorMessage = t("service.weak_password")
        } else if message.contains("TOO_MANY_ATTEMPTS") {
            errorMessage = t("service.too_many_attempts")
        } else if message.contains("NETWORK") || message.contains("OFFLINE") {
            errorMessage = t("service.network_error")
        } else {
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
            throw FirebaseRESTError.requestFailed(t("service.no_session"))
        }
        if authSession?.isExpired == true {
            return try await forceRefreshToken()
        }
        return authSession!
    }

    private func forceRefreshToken() async throws -> FirebaseAuthSession {
        guard let firebaseClient else {
            throw FirebaseRESTError.requestFailed(t("service.firebase_missing"))
        }
        guard let current = authSession else {
            throw FirebaseRESTError.requestFailed(t("service.no_session"))
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

    private static func restoreLanguage() -> AppLanguage {
        AppLanguage(code: UserDefaults.standard.string(forKey: languageDefaultsKey) ?? AppLanguage.tr.rawValue)
    }

    private static func restoreDestination() -> JourneyDestination? {
        guard let data = UserDefaults.standard.data(forKey: destinationDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(JourneyDestination.self, from: data)
    }

    private static func restoreRecentRoutes() -> [RecentStationRoute] {
        guard let data = UserDefaults.standard.data(forKey: recentRoutesDefaultsKey) else { return [] }
        return (try? JSONDecoder().decode([RecentStationRoute].self, from: data)) ?? []
    }

    private static func restoreReportCooldowns() -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: reportCooldownsDefaultsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: Date].self, from: data)) ?? [:]
    }

    private func persistProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.profileDefaultsKey)
        }
    }

    private func persistLanguage() {
        UserDefaults.standard.set(language.rawValue, forKey: Self.languageDefaultsKey)
    }

    private func persistDestination() {
        guard let destination else {
            UserDefaults.standard.removeObject(forKey: Self.destinationDefaultsKey)
            return
        }
        if let data = try? JSONEncoder().encode(destination) {
            UserDefaults.standard.set(data, forKey: Self.destinationDefaultsKey)
        }
    }

    private func persistRecentRoutes() {
        if let data = try? JSONEncoder().encode(recentRoutes) {
            UserDefaults.standard.set(data, forKey: Self.recentRoutesDefaultsKey)
        }
    }

    private func persistReportCooldowns() {
        reportCooldowns = reportCooldowns.filter {
            Date().timeIntervalSince($0.value) < 24 * 60 * 60
        }
        if let data = try? JSONEncoder().encode(reportCooldowns) {
            UserDefaults.standard.set(data, forKey: Self.reportCooldownsDefaultsKey)
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

    private func applyDebugLaunchMode() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing-home") || arguments.contains("--ui-testing-routes") {
            tab = .home
            userLocation = UserLocation(latitude: 38.3939, longitude: 27.1891, source: .manual)
        } else if arguments.contains("--ui-testing-lounge") {
            tab = .lounge
        }
        #endif
    }
}

struct RecentStationRoute: Codable, Hashable, Identifiable {
    var stationID: String
    var stationKey: String
    var openedAt: Date

    var id: String { stationID }
}

private struct EmptyStationRepository: StationRepository {
    func loadStations() async throws -> [Station] {
        throw StationRepositoryError.missingResource
    }
}
