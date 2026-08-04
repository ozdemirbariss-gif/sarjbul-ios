import Foundation

public protocol AuthClient: Sendable {
    func signInAnonymously() async throws -> FirebaseAuthSession
    func initiateAccountDeletion(uid: String, idToken: String) async throws
    func deleteAccount(idToken: String) async throws
    func refreshSession(refreshToken: String) async throws -> FirebaseAuthSession
}

public protocol FavoritesClient: Sendable {
    func favoriteIDs(uid: String, idToken: String) async throws -> Set<String>
    func setFavorite(uid: String, stationKey: String, isFavorite: Bool, idToken: String) async throws
}

public protocol StatusClient: Sendable {
    func stationStatuses(idToken: String?) async throws -> [String: StationStatusSummary]
    func stationCommunityInsights(idToken: String?) async throws -> [String: StationCommunityInsight]
    func sendStationReport(
        stationKey: String,
        status: String,
        comment: String,
        uid: String,
        idToken: String
    ) async throws
    func sendStationContribution(
        stationKey: String,
        contribution: StationContribution,
        uid: String,
        idToken: String
    ) async throws
}

public protocol DemandAnalyticsClient: Sendable {
    func recordSearchDemand(
        event: SearchDemandEvent,
        uid: String,
        idToken: String
    ) async throws
}

public enum ServiceClientError: LocalizedError, Equatable, Sendable {
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Service is not configured."
        }
    }
}

public struct UnavailableAuthClient: AuthClient {
    public init() {}

    public func signInAnonymously() async throws -> FirebaseAuthSession { throw ServiceClientError.notConfigured }
    public func initiateAccountDeletion(uid: String, idToken: String) async throws { throw ServiceClientError.notConfigured }
    public func deleteAccount(idToken: String) async throws { throw ServiceClientError.notConfigured }
    public func refreshSession(refreshToken: String) async throws -> FirebaseAuthSession { throw ServiceClientError.notConfigured }
}

public struct UnavailableFavoritesClient: FavoritesClient {
    public init() {}

    public func favoriteIDs(uid: String, idToken: String) async throws -> Set<String> { throw ServiceClientError.notConfigured }
    public func setFavorite(uid: String, stationKey: String, isFavorite: Bool, idToken: String) async throws { throw ServiceClientError.notConfigured }
}

public struct UnavailableStatusClient: StatusClient {
    public init() {}

    public func stationStatuses(idToken: String?) async throws -> [String: StationStatusSummary] { [:] }
    public func stationCommunityInsights(idToken: String?) async throws -> [String: StationCommunityInsight] { [:] }

    public func sendStationReport(
        stationKey: String,
        status: String,
        comment: String,
        uid: String,
        idToken: String
    ) async throws {
        throw ServiceClientError.notConfigured
    }

    public func sendStationContribution(
        stationKey: String,
        contribution: StationContribution,
        uid: String,
        idToken: String
    ) async throws {
        throw ServiceClientError.notConfigured
    }
}

public struct UnavailableDemandAnalyticsClient: DemandAnalyticsClient {
    public init() {}

    public func recordSearchDemand(
        event: SearchDemandEvent,
        uid: String,
        idToken: String
    ) async throws {}
}

public enum AuthError: LocalizedError, Equatable, Sendable {
    case tooManyAttempts
    case network
    case sessionExpired
    case sessionInvalidated
    case serviceUnavailable
    case other(String)

    public var errorDescription: String? {
        switch self {
        case .tooManyAttempts: "Too many attempts."
        case .network: "Network connection failed."
        case .sessionExpired: "Authentication session expired."
        case .sessionInvalidated: "Authentication session is no longer valid."
        case .serviceUnavailable: "Authentication service is unavailable."
        case .other(let message): message
        }
    }

    public static func map(_ error: Error) -> AuthError {
        if let authError = error as? AuthError { return authError }
        if error is ServiceClientError { return .serviceUnavailable }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost:
                return .network
            default:
                break
            }
        }

        let message = error.localizedDescription.uppercased()
        if message.contains("TOO_MANY_ATTEMPTS") { return .tooManyAttempts }
        if message.contains("INVALID_REFRESH_TOKEN") || message.contains("USER_DISABLED") ||
            message.contains("USER_NOT_FOUND") {
            return .sessionInvalidated
        }
        if message.contains("TOKEN_EXPIRED") || message.contains("INVALID_ID_TOKEN") { return .sessionExpired }
        if message.contains("NETWORK") || message.contains("OFFLINE") { return .network }
        return .other(error.localizedDescription)
    }
}

extension FirebaseRESTClient: AuthClient, FavoritesClient, StatusClient, DemandAnalyticsClient {}
