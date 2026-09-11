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
    private let deletionPollAttempts: Int
    private var isDeleting = false
    private(set) var pendingDeletion: PendingAccountDeletion?
    let isConfigured: Bool
    private(set) var state: AuthState
    var onSessionChanged: (@MainActor (FirebaseAuthSession?) async -> Void)?

    init(
        client: any AuthClient,
        persistence: any AppPersistence,
        messages: AppMessagePresenter,
        isConfigured: Bool,
        deletionPollAttempts: Int = 6
    ) {
        self.client = client
        self.persistence = persistence
        self.messages = messages
        self.isConfigured = isConfigured
        self.deletionPollAttempts = max(1, deletionPollAttempts)
        pendingDeletion = persistence.pendingAccountDeletion
        if let session = persistence.authSession, !session.uid.isEmpty {
            state = .active(session)
        } else {
            state = .local
        }
    }

    var session: FirebaseAuthSession? { pendingDeletion == nil ? state.session : nil }

    func prepare() async {
        guard isConfigured else { return }
        if pendingDeletion != nil {
            _ = await deleteAccount()
            return
        }
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
        guard !isDeleting else { return false }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try requireConfiguration()
            var deletionSession: FirebaseAuthSession
            if let current = state.session { deletionSession = current } else { deletionSession = try await validSession() }
            if let pendingDeletion, pendingDeletion.uid != deletionSession.uid { throw AuthError.sessionExpired }
            if deletionSession.isExpired {
                do {
                    let refreshed = try await client.refreshSession(refreshToken: deletionSession.refreshToken)
                    deletionSession = try preservingIdentity(refreshed, current: deletionSession)
                    state = .active(deletionSession)
                    persistence.authSession = deletionSession
                } catch let error as AuthError where error == .sessionInvalidated && pendingDeletion?.serverConfirmed == true {
                    await finishDeletion()
                    return true
                }
            }
            if pendingDeletion == nil {
                saveDeletion(PendingAccountDeletion(uid: deletionSession.uid))
                await onSessionChanged?(nil)
            }
            if pendingDeletion?.serverConfirmed != true {
                try await client.initiateAccountDeletion(uid: deletionSession.uid, idToken: deletionSession.idToken)
                for attempt in 0..<deletionPollAttempts {
                    let status = try await client.accountDeletionStatus(uid: deletionSession.uid, idToken: deletionSession.idToken)
                    if status == .completed {
                        saveDeletion(PendingAccountDeletion(uid: deletionSession.uid, serverConfirmed: true))
                        break
                    }
                    if attempt + 1 < deletionPollAttempts { try await Task.sleep(for: .milliseconds(500)) }
                }
            }
            guard pendingDeletion?.serverConfirmed == true else {
                messages.present(.localized(key: "service.account_deletion_pending", kind: .information))
                return false
            }
            try await client.deleteAccount(idToken: deletionSession.idToken)
            await finishDeletion()
            return true
        } catch {
            AppLogger.account.error("Account deletion failed: \(error.localizedDescription, privacy: .public)")
            present(error)
            return false
        }
    }

    private func saveDeletion(_ value: PendingAccountDeletion?) {
        pendingDeletion = value
        persistence.pendingAccountDeletion = value
    }

    private func finishDeletion() async {
        persistence.pendingOfflineMutations = []
        persistence.favoriteStationKeys = []
        persistence.reportCooldowns = [:]
        saveDeletion(nil)
        await clearSession()
        await prepare()
        messages.present(.localized(key: "service.account_deleted", kind: .success))
    }

    func authenticatedRequest<T: Sendable>(
        _ operation: @MainActor (FirebaseAuthSession) async throws -> T
    ) async throws -> T {
        let initial = try await validSession()
        do {
            return try await operation(initial)
        } catch let error as FirebaseRESTError where error.isUnauthorized {
            return try await retryAuthenticatedRequest(for: initial, operation)
        } catch let error as AuthError where error == .sessionExpired {
            return try await retryAuthenticatedRequest(for: initial, operation)
        }
    }

    private func retryAuthenticatedRequest<T: Sendable>(
        for initial: FirebaseAuthSession, _ operation: @MainActor (FirebaseAuthSession) async throws -> T
    ) async throws -> T {
        guard pendingDeletion == nil, state.session?.uid == initial.uid else { throw AuthError.serviceUnavailable }
        let refreshed = try await refreshSession()
        guard refreshed.uid == initial.uid else { throw AuthError.sessionExpired }
        return try await operation(refreshed)
    }

    func validSession() async throws -> FirebaseAuthSession {
        guard pendingDeletion == nil else { throw AuthError.serviceUnavailable }
        guard let session = state.session else {
            return try await createAnonymousSession()
        }
        if session.isExpired { return try await refreshSession() }
        return session
    }

    private func createAnonymousSession() async throws -> FirebaseAuthSession {
        try requireConfiguration()
        guard pendingDeletion == nil else { throw AuthError.serviceUnavailable }
        let session = try await client.signInAnonymously()
        guard pendingDeletion == nil else { throw AuthError.serviceUnavailable }
        await apply(session)
        return session
    }

    private func refreshSession() async throws -> FirebaseAuthSession {
        guard pendingDeletion == nil else { throw AuthError.serviceUnavailable }
        guard let current = state.session else { throw AuthError.sessionExpired }
        state = .refreshing(current)
        do {
            let response = try await client.refreshSession(refreshToken: current.refreshToken)
            guard pendingDeletion == nil, state.session?.uid == current.uid else { throw AuthError.serviceUnavailable }
            let refreshed = try preservingIdentity(response, current: current)
            await apply(refreshed)
            return refreshed
        } catch let error as AuthError where error == .sessionInvalidated {
            guard pendingDeletion == nil, state.session?.uid == current.uid else { throw AuthError.serviceUnavailable }
            await clearSession()
            return try await createAnonymousSession()
        } catch {
            if pendingDeletion == nil, state.session?.uid == current.uid { state = .active(current) }
            throw error
        }
    }

    private func preservingIdentity(
        _ response: FirebaseAuthSession, current: FirebaseAuthSession
    ) throws -> FirebaseAuthSession {
        guard response.uid.isEmpty || response.uid == current.uid else { throw AuthError.sessionExpired }
        var refreshed = response
        refreshed.email = refreshed.email ?? current.email
        refreshed.localId = refreshed.localId ?? current.localId
        refreshed.userId = refreshed.userId ?? current.userId
        return refreshed
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
