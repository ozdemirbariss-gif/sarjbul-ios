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

    func testTransientRefreshFailurePreservesAnonymousIdentity() async throws {
        let persistence = try makePersistence()
        let current = expiredSession(uid: "stable-driver")
        persistence.authSession = current
        let store = AuthStore(
            client: RefreshFailingAuthClient(error: .network, replacement: current),
            persistence: persistence,
            messages: AppMessagePresenter(),
            isConfigured: true
        )

        do {
            _ = try await store.validSession()
            XCTFail("A transient refresh error should be surfaced to the caller")
        } catch {
            XCTAssertEqual(error as? AuthError, .network)
        }
        XCTAssertEqual(store.state, .active(current))
        XCTAssertEqual(persistence.authSession?.uid, "stable-driver")
    }

    func testInvalidRefreshTokenCreatesReplacementAnonymousIdentity() async throws {
        let persistence = try makePersistence()
        let current = expiredSession(uid: "invalid-driver")
        let replacement = FirebaseAuthSession(
            idToken: "new-id-token",
            refreshToken: "new-refresh-token",
            localId: "replacement-driver"
        )
        persistence.authSession = current
        let store = AuthStore(
            client: RefreshFailingAuthClient(error: .sessionInvalidated, replacement: replacement),
            persistence: persistence,
            messages: AppMessagePresenter(),
            isConfigured: true
        )

        let result = try await store.validSession()

        XCTAssertEqual(result.uid, "replacement-driver")
        XCTAssertEqual(persistence.authSession?.uid, "replacement-driver")
    }

    func testActiveChargingSessionRestoresFromPersistence() throws {
        let persistence = try makePersistence()
        let station = Station(
            id: "station-1",
            name: "Test Station",
            address: "Izmir",
            latitude: 38.4,
            longitude: 27.1,
            power: "150 kW",
            operatorName: "Test",
            socket: "CCS2",
            price: "10 TL",
            source: "test"
        )
        let saved = PersistedChargingSession(
            station: station,
            endDate: Date().addingTimeInterval(1_800),
            targetPercent: 85
        )
        persistence.activeChargingSession = saved

        let store = ChargingSessionStore(persistence: persistence)

        XCTAssertTrue(store.isActive)
        XCTAssertEqual(store.station?.id, station.id)
        XCTAssertEqual(store.endDate, saved.endDate)
        XCTAssertEqual(store.targetPercent, 85)
    }

    func testAutonomousMuteWindowPersists() throws {
        let persistence = try makePersistence()
        let mutedUntil = Date(timeIntervalSince1970: 1_800_000_000)

        persistence.autonomousChargingMutedUntil = mutedUntil

        XCTAssertEqual(persistence.autonomousChargingMutedUntil, mutedUntil)
    }

    private func makePersistence() throws -> SystemAppPersistence {
        let suiteName = "StoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return SystemAppPersistence(defaults: defaults, secureStorage: MemorySecureStorage())
    }

    private func expiredSession(uid: String) -> FirebaseAuthSession {
        FirebaseAuthSession(
            idToken: "expired-id-token",
            refreshToken: "refresh-token",
            expiresIn: "60",
            issuedAt: Date().addingTimeInterval(-120),
            localId: uid
        )
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

private struct RefreshFailingAuthClient: AuthClient {
    let error: AuthError
    let replacement: FirebaseAuthSession

    func signInAnonymously() async throws -> FirebaseAuthSession { replacement }
    func initiateAccountDeletion(uid: String, idToken: String) async throws {}
    func deleteAccount(idToken: String) async throws {}
    func refreshSession(refreshToken: String) async throws -> FirebaseAuthSession { throw error }
}
