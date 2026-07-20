import Foundation

public protocol AuthClient: Sendable {
    func signIn(email: String, password: String) async throws -> FirebaseAuthSession
    func signUp(email: String, password: String) async throws -> FirebaseAuthSession
    func sendPasswordReset(email: String) async throws
    func sendEmailVerification(idToken: String) async throws
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

    public func signIn(email: String, password: String) async throws -> FirebaseAuthSession { throw ServiceClientError.notConfigured }
    public func signUp(email: String, password: String) async throws -> FirebaseAuthSession { throw ServiceClientError.notConfigured }
    public func sendPasswordReset(email: String) async throws { throw ServiceClientError.notConfigured }
    public func sendEmailVerification(idToken: String) async throws { throw ServiceClientError.notConfigured }
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
    case invalidCredentials
    case emailAlreadyExists
    case weakPassword
    case tooManyAttempts
    case network
    case sessionExpired
    case serviceUnavailable
    case other(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials: "Invalid login credentials."
        case .emailAlreadyExists: "Email already exists."
        case .weakPassword: "Password is too weak."
        case .tooManyAttempts: "Too many attempts."
        case .network: "Network connection failed."
        case .sessionExpired: "Authentication session expired."
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
        if message.contains("INVALID_LOGIN_CREDENTIALS")
            || message.contains("INVALID_PASSWORD")
            || message.contains("EMAIL_NOT_FOUND") {
            return .invalidCredentials
        }
        if message.contains("EMAIL_EXISTS") { return .emailAlreadyExists }
        if message.contains("WEAK_PASSWORD") { return .weakPassword }
        if message.contains("TOO_MANY_ATTEMPTS") { return .tooManyAttempts }
        if message.contains("TOKEN_EXPIRED") || message.contains("INVALID_ID_TOKEN") { return .sessionExpired }
        if message.contains("NETWORK") || message.contains("OFFLINE") { return .network }
        return .other(error.localizedDescription)
    }
}

extension FirebaseRESTClient: AuthClient, FavoritesClient, StatusClient, DemandAnalyticsClient {}
