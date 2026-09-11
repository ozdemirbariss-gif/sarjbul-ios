import Foundation
import SarjBulCore
import XCTest
@testable import SarjBul

@MainActor
final class AccountDeletionTests: XCTestCase {
    func testPendingDeletionPreservesIdentityAndLocalDataWithoutClaimingSuccess() async throws {
        let (persistence, client, store, messages) = try fixture()
        let result = await store.deleteAccount()

        XCTAssertFalse(result)
        XCTAssertNil(store.session)
        XCTAssertEqual(persistence.authSession?.uid, "owner")
        XCTAssertEqual(persistence.favoriteStationKeys, ["saved-station"])
        XCTAssertEqual(persistence.pendingAccountDeletion, PendingAccountDeletion(uid: "owner"))
        XCTAssertEqual(messages.current?.kind, .information)
        let deleted = await client.deletedTokens
        XCTAssertTrue(deleted.isEmpty)
        do {
            _ = try await store.validSession()
            XCTFail("Pending deletion must pause authenticated writes")
        } catch {
            XCTAssertEqual(error as? AuthError, .serviceUnavailable)
        }
    }

    func testRelaunchResumesReceiptAndOnlyThenReplacesIdentity() async throws {
        let (persistence, client, firstStore, _) = try fixture()
        _ = await firstStore.deleteAccount()
        await client.setStatus(.completed)
        let messages = AppMessagePresenter()
        let relaunchedStore = makeStore(persistence, client, messages)

        await relaunchedStore.prepare()

        XCTAssertNil(persistence.pendingAccountDeletion)
        XCTAssertEqual(relaunchedStore.session?.uid, "replacement")
        XCTAssertTrue(persistence.favoriteStationKeys.isEmpty)
        XCTAssertEqual(messages.current?.kind, .success)
        let deleted = await client.deletedTokens
        XCTAssertEqual(deleted, ["owner-token"])
    }

    func testReceiptReadFailureDoesNotDeleteAuthOrClearLocalData() async throws {
        let (persistence, client, store, messages) = try fixture()
        await client.setStatusFailure(true)
        let result = await store.deleteAccount()

        XCTAssertFalse(result)
        XCTAssertEqual(persistence.authSession?.uid, "owner")
        XCTAssertEqual(persistence.favoriteStationKeys, ["saved-station"])
        XCTAssertEqual(messages.current?.kind, .error)
        let deleted = await client.deletedTokens
        XCTAssertTrue(deleted.isEmpty)
    }

    func testConfirmedReceiptSurvivesAuthDeletionFailureAndRetry() async throws {
        let (persistence, client, store, _) = try fixture()
        await client.setStatus(.completed)
        await client.setDeletionFailure(true)
        let firstResult = await store.deleteAccount()
        XCTAssertFalse(firstResult)
        XCTAssertEqual(persistence.pendingAccountDeletion?.serverConfirmed, true)
        XCTAssertEqual(persistence.authSession?.uid, "owner")
        await client.setDeletionFailure(false)
        // A previously confirmed receipt need not be fetched again after relaunch.
        await client.setStatusFailure(true)
        let secondResult = await makeStore(persistence, client).deleteAccount()
        XCTAssertTrue(secondResult)
        XCTAssertNil(persistence.pendingAccountDeletion)
        XCTAssertEqual(persistence.authSession?.uid, "replacement")
    }

    func testExpiredInvalidIdentityCannotClaimUnconfirmedServerCleanup() async throws {
        let (persistence, client, _, _) = try fixture()
        persistence.authSession = expiredSession()
        persistence.pendingAccountDeletion = PendingAccountDeletion(uid: "owner")
        await client.setRefreshError(.sessionInvalidated)
        let result = await makeStore(persistence, client).deleteAccount()
        XCTAssertFalse(result)
        XCTAssertEqual(persistence.authSession?.uid, "owner")
        XCTAssertEqual(persistence.pendingAccountDeletion?.serverConfirmed, false)
        let signIns = await client.signIns
        XCTAssertEqual(signIns, 0)
    }

    func testLostAuthDeletionResponseRecoversOnlyWithPersistedServerConfirmation() async throws {
        let (persistence, client, _, _) = try fixture()
        persistence.authSession = expiredSession()
        persistence.pendingAccountDeletion = PendingAccountDeletion(uid: "owner", serverConfirmed: true)
        await client.setRefreshError(.sessionInvalidated)
        let result = await makeStore(persistence, client).deleteAccount()
        XCTAssertTrue(result)
        XCTAssertNil(persistence.pendingAccountDeletion)
        XCTAssertEqual(persistence.authSession?.uid, "replacement")
    }

    func testRefreshCannotSwitchDeletionToAnotherIdentity() async throws {
        let (persistence, client, _, _) = try fixture()
        persistence.authSession = expiredSession()
        persistence.pendingAccountDeletion = PendingAccountDeletion(uid: "owner")
        await client.setRefreshedUID("other")
        let result = await makeStore(persistence, client).deleteAccount()
        XCTAssertFalse(result)
        XCTAssertEqual(persistence.authSession?.uid, "owner")
        let deleted = await client.deletedTokens
        XCTAssertTrue(deleted.isEmpty)
    }

    func testLateUnauthorizedResponseCannotReplayUnderReplacementIdentity() async throws {
        let (_, client, store, _) = try fixture()
        await client.setStatus(.completed)
        var calls = 0
        do {
            _ = try await store.authenticatedRequest { _ -> Bool in
                calls += 1
                _ = await store.deleteAccount()
                throw FirebaseRESTError.requestFailed("Expired old token", statusCode: 401)
            }
            XCTFail("An operation from the deleted identity must not be replayed")
        } catch {
            XCTAssertEqual(error as? AuthError, .serviceUnavailable)
        }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(store.session?.uid, "replacement")
    }

    func testPendingReceiptIsStoredSecurelyAcrossPersistenceInstances() throws {
        let suite = "DeletionPersistence.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let secureStorage = DeletionSecureStorage()
        let persistence = SystemAppPersistence(defaults: defaults, secureStorage: secureStorage)
        let pending = PendingAccountDeletion(uid: "owner", serverConfirmed: true)
        persistence.pendingAccountDeletion = pending
        let restored = SystemAppPersistence(defaults: defaults, secureStorage: secureStorage)
        XCTAssertEqual(restored.pendingAccountDeletion, pending)
        XCTAssertNil(defaults.data(forKey: "pendingAccountDeletion"))
        XCTAssertNotNil(secureStorage.data(for: "pendingAccountDeletion"))
    }

    private func fixture() throws -> (SystemAppPersistence, DeletionAuthClient, AuthStore, AppMessagePresenter) {
        let suite = "AccountDeletionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let persistence = SystemAppPersistence(defaults: defaults, secureStorage: DeletionSecureStorage())
        persistence.authSession = FirebaseAuthSession(idToken: "owner-token", refreshToken: "refresh", localId: "owner")
        persistence.favoriteStationKeys = ["saved-station"]
        let client = DeletionAuthClient()
        let messages = AppMessagePresenter()
        return (persistence, client, makeStore(persistence, client, messages), messages)
    }

    private func makeStore(
        _ persistence: SystemAppPersistence, _ client: DeletionAuthClient,
        _ messages: AppMessagePresenter = AppMessagePresenter()
    ) -> AuthStore {
        AuthStore(client: client, persistence: persistence, messages: messages, isConfigured: true, deletionPollAttempts: 1)
    }

    private func expiredSession() -> FirebaseAuthSession {
        FirebaseAuthSession(
            idToken: "owner-token", refreshToken: "refresh", expiresIn: "60",
            issuedAt: Date().addingTimeInterval(-120), localId: "owner"
        )
    }
}

private final class DeletionSecureStorage: SecureStorage {
    private var values: [String: Data] = [:]
    func data(for key: String) -> Data? { values[key] }
    func set(_ data: Data, for key: String) { values[key] = data }
    func remove(_ key: String) { values.removeValue(forKey: key) }
}

private actor DeletionAuthClient: AuthClient {
    var status: AccountDeletionStatus = .pending
    var statusFailure = false
    var deletionFailure = false
    var refreshError: AuthError?
    var refreshedUID = "owner"
    private(set) var deletedTokens: [String] = []
    private(set) var signIns = 0

    func setStatus(_ value: AccountDeletionStatus) { status = value }
    func setStatusFailure(_ value: Bool) { statusFailure = value }
    func setDeletionFailure(_ value: Bool) { deletionFailure = value }
    func setRefreshError(_ value: AuthError) { refreshError = value }
    func setRefreshedUID(_ value: String) { refreshedUID = value }

    func signInAnonymously() async throws -> FirebaseAuthSession {
        signIns += 1
        return FirebaseAuthSession(idToken: "new-token", refreshToken: "new-refresh", localId: "replacement")
    }
    func initiateAccountDeletion(uid: String, idToken: String) async throws {}
    func accountDeletionStatus(uid: String, idToken: String) async throws -> AccountDeletionStatus? {
        if statusFailure { throw AuthError.network }
        return status
    }
    func deleteAccount(idToken: String) async throws {
        if deletionFailure { throw AuthError.network }
        deletedTokens.append(idToken)
    }
    func refreshSession(refreshToken: String) async throws -> FirebaseAuthSession {
        if let refreshError { throw refreshError }
        return FirebaseAuthSession(idToken: "refreshed", refreshToken: "refresh", userId: refreshedUID)
    }
}
