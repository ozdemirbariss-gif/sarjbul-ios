import Foundation
import SarjBulCore
import XCTest
@testable import SarjBul

@MainActor
final class PersistenceTests: XCTestCase {
    func testLegacyAuthSessionMigratesFromDefaultsToSecureStorage() throws {
        let suiteName = "PersistenceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let secureStorage = MemorySecureStorage()
        let session = FirebaseAuthSession(
            idToken: "id-token",
            email: "driver@example.com",
            refreshToken: "refresh-token",
            localId: "driver"
        )
        defaults.set(try JSONEncoder().encode(session), forKey: "firebaseAuthSession")

        let persistence = SystemAppPersistence(defaults: defaults, secureStorage: secureStorage)

        XCTAssertEqual(persistence.authSession, session)
        XCTAssertNil(defaults.data(forKey: "firebaseAuthSession"))
        XCTAssertNotNil(secureStorage.data(for: "firebaseAuthSession"))
    }

    func testAuthStoreCreatesAnonymousSessionWithoutUserInput() async throws {
        let suiteName = "AuthStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = SystemAppPersistence(
            defaults: defaults,
            secureStorage: MemorySecureStorage()
        )
        let expected = FirebaseAuthSession(
            idToken: "id-token",
            refreshToken: "refresh-token",
            localId: "anonymous-driver"
        )
        let store = AuthStore(
            client: StubAuthClient(session: expected),
            persistence: persistence,
            messages: AppMessagePresenter(),
            isConfigured: true
        )

        await store.prepare()

        XCTAssertEqual(store.state, .active(expected))
        XCTAssertEqual(persistence.authSession, expected)
    }
}

private final class MemorySecureStorage: SecureStorage {
    private var values: [String: Data] = [:]

    func data(for key: String) -> Data? { values[key] }
    func set(_ data: Data, for key: String) { values[key] = data }
    func remove(_ key: String) { values.removeValue(forKey: key) }
}

private struct StubAuthClient: AuthClient {
    let session: FirebaseAuthSession

    func signInAnonymously() async throws -> FirebaseAuthSession { session }
    func initiateAccountDeletion(uid: String, idToken: String) async throws {}
    func deleteAccount(idToken: String) async throws {}
    func refreshSession(refreshToken: String) async throws -> FirebaseAuthSession { session }
}
