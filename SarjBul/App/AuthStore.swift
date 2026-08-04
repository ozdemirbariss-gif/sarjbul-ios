import Observation
import SarjBulCore

enum AuthState: Equatable, Sendable {
    case local
    case active(FirebaseAuthSession)
    case refreshing(FirebaseAuthSession)

    var session: FirebaseAuthSession? {
        switch self {
        case .local: nil
        case .active(let session), .refreshing(let session): session
        }
    }
}

@MainActor
@Observable
final class AuthStore {
    private let client: any AuthClient
    private let persistence: any AppPersistence
    private let messages: AppMessagePresenter
    let isConfigured: Bool
    private(set) var state: AuthState
    var onSessionChanged: (@MainActor (FirebaseAuthSession?) async -> Void)?

    init(
        client: any AuthClient,
        persistence: any AppPersistence,
        messages: AppMessagePresenter,
        isConfigured: Bool
    ) {
        self.client = client
        self.persistence = persistence
        self.messages = messages
        self.isConfigured = isConfigured
        if let session = persistence.authSession, !session.uid.isEmpty {
            state = .active(session)
        } else {
            state = .local
        }
    }

    var session: FirebaseAuthSession? { state.session }

    func prepare() async {
        guard isConfigured else { return }
        do {
            _ = try await validSession()
        } catch {
            AppLogger.account.warning(
                "Anonymous session could not be prepared: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func clearSession() async {
        state = .local
        persistence.authSession = nil
        await onSessionChanged?(nil)
    }

    func deleteAccount() async -> Bool {
        do {
            try requireConfiguration()
            let session = try await validSession()
            try await client.initiateAccountDeletion(uid: session.uid, idToken: session.idToken)
            try await client.deleteAccount(idToken: session.idToken)
            await clearSession()
            await prepare()
            messages.present(.localized(key: "service.account_deleted", kind: .success))
            return true
        } catch {
            AppLogger.account.error("Account deletion failed: \(error.localizedDescription, privacy: .public)")
            present(error)
            return false
        }
    }

    func authenticatedRequest<T: Sendable>(
        _ operation: @MainActor (FirebaseAuthSession) async throws -> T
    ) async throws -> T {
        do {
            return try await operation(try await validSession())
        } catch let error as FirebaseRESTError where error.isUnauthorized {
            return try await operation(try await refreshSession())
        } catch let error as AuthError where error == .sessionExpired {
            return try await operation(try await refreshSession())
        }
    }

    func validSession() async throws -> FirebaseAuthSession {
        guard let session = state.session else {
            return try await createAnonymousSession()
        }
        if session.isExpired { return try await refreshSession() }
        return session
    }

    private func createAnonymousSession() async throws -> FirebaseAuthSession {
        try requireConfiguration()
        let session = try await client.signInAnonymously()
        await apply(session)
        return session
    }

    private func refreshSession() async throws -> FirebaseAuthSession {
        guard let current = state.session else { throw AuthError.sessionExpired }
        state = .refreshing(current)
        do {
            var refreshed = try await client.refreshSession(refreshToken: current.refreshToken)
            refreshed.email = refreshed.email ?? current.email
            refreshed.localId = refreshed.localId ?? current.localId
            refreshed.userId = refreshed.userId ?? current.userId
            await apply(refreshed)
            return refreshed
        } catch let error as AuthError where error == .sessionInvalidated {
            await clearSession()
            return try await createAnonymousSession()
        } catch {
            state = .active(current)
            throw error
        }
    }

    private func apply(_ session: FirebaseAuthSession) async {
        state = .active(session)
        persistence.authSession = session
        await onSessionChanged?(session)
    }

    private func requireConfiguration() throws {
        guard isConfigured else { throw AuthError.serviceUnavailable }
    }

    private func present(_ error: Error) {
        messages.present(.auth(AuthError.map(error)))
    }
}
