import Observation
import SarjBulCore

enum AuthState: Equatable, Sendable {
    case guest
    case signedIn(FirebaseAuthSession)
    case refreshing(FirebaseAuthSession)

    var session: FirebaseAuthSession? {
        switch self {
        case .guest: nil
        case .signedIn(let session), .refreshing(let session): session
        }
    }

    var isAuthenticated: Bool {
        session?.uid.isEmpty == false
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
            state = .signedIn(session)
        } else {
            state = .guest
        }
    }

    var session: FirebaseAuthSession? { state.session }
    var isAuthenticated: Bool { state.isAuthenticated }

    func signIn(email: String, password: String) async {
        do {
            try requireConfiguration()
            let session = try await client.signIn(email: email, password: password)
            await apply(session)
        } catch {
            present(error)
        }
    }

    func signUp(email: String, password: String) async {
        do {
            try requireConfiguration()
            let session = try await client.signUp(email: email, password: password)
            await apply(session)
            var verificationSent = false
            do {
                try await client.sendEmailVerification(idToken: session.idToken)
                verificationSent = true
            } catch {
                AppLogger.account.warning("Verification email failed: \(error.localizedDescription, privacy: .public)")
            }
            messages.present(.localized(
                key: verificationSent ? "service.verification_sent" : "service.verification_pending",
                kind: .success
            ))
        } catch {
            present(error)
        }
    }

    func resetPassword(email: String) async {
        do {
            try requireConfiguration()
            try await client.sendPasswordReset(email: email)
            messages.present(.localized(key: "service.reset_sent", kind: .success))
        } catch {
            present(error)
        }
    }

    func signOut() {
        state = .guest
        persistence.authSession = nil
        Task { await onSessionChanged?(nil) }
    }

    func deleteAccount() async -> Bool {
        do {
            try requireConfiguration()
            let session = try await validSession()
            try await client.initiateAccountDeletion(uid: session.uid, idToken: session.idToken)
            try await client.deleteAccount(idToken: session.idToken)
            signOut()
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
        guard let session = state.session else { throw AuthError.sessionExpired }
        if session.isExpired { return try await refreshSession() }
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
        } catch {
            state = .guest
            persistence.authSession = nil
            await onSessionChanged?(nil)
            throw AuthError.map(error)
        }
    }

    private func apply(_ session: FirebaseAuthSession) async {
        state = .signedIn(session)
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
