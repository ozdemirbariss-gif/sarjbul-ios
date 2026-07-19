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

    func testAuthStoreUsesSignedInStateAfterClientSuccess() async throws {
        let suiteName = "AuthStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = SystemAppPersistence(
            defaults: defaults,
            secureStorage: MemorySecureStorage()
        )
        let expected = FirebaseAuthSession(
            idToken: "id-token",
            email: "driver@example.com",
            refreshToken: "refresh-token",
            localId: "driver"
        )
        let store = AuthStore(
            client: StubAuthClient(session: expected),
            persistence: persistence,
            messages: AppMessagePresenter(),
            isConfigured: true
        )

        await store.signIn(email: "driver@example.com", password: "secret")

        XCTAssertEqual(store.state, .signedIn(expected))
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

    func signIn(email: String, password: String) async throws -> FirebaseAuthSession { session }
    func signUp(email: String, password: String) async throws -> FirebaseAuthSession { session }
    func sendPasswordReset(email: String) async throws {}
    func sendEmailVerification(idToken: String) async throws {}
    func initiateAccountDeletion(uid: String, idToken: String) async throws {}
    func deleteAccount(idToken: String) async throws {}
    func refreshSession(refreshToken: String) async throws -> FirebaseAuthSession { session }
}
