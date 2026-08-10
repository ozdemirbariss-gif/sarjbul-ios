import Foundation
import SarjBulCore
import XCTest
@testable import SarjBul

@MainActor
final class PersistenceTests: XCTestCase {
    func testEnglishUppercaseDoesNotUseTurkishDottedCapitalI() {
        let title = AppLanguage.en.uppercased("driving profile")

        XCTAssertEqual(title, "DRIVING PROFILE")
        XCTAssertFalse(title.contains("İ"))
        XCTAssertEqual(AppLanguage.tr.uppercased("sürüş profili"), "SÜRÜŞ PROFİLİ")
    }

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

    func testAutomationReportsPersistNewestFirst() throws {
        let persistence = try makePersistence()
        let report = AutomationReport(
            rule: .preparedRouteRisky,
            actions: [.refreshStationData, .replacePreparedRoute],
            previousStationName: "Old Station",
            selectedStationName: "Safe Station"
        )

        persistence.automationReports = [report]

        XCTAssertEqual(persistence.automationReports, [report])
    }

    func testOfflineMutationOutboxSurvivesRelaunch() throws {
        let suiteName = "OfflineOutboxTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let secureStorage = MemorySecureStorage()
        let persistence = SystemAppPersistence(defaults: defaults, secureStorage: secureStorage)
        let mutation = PendingOfflineMutation(
            id: "offline-1",
            deduplicationKey: "favorite:station-1",
            payload: .favorite(stationKey: "station-1", isFavorite: true),
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        persistence.pendingOfflineMutations = [mutation]

        XCTAssertEqual(persistence.pendingOfflineMutations.map(\.id), ["offline-1"])
        XCTAssertNil(defaults.data(forKey: "pendingOfflineMutations"))
        XCTAssertNotNil(secureStorage.data(for: "pendingOfflineMutations"))
    }

    func testFavoriteSnapshotIsAvailableOffline() throws {
        let persistence = try makePersistence()

        persistence.favoriteStationKeys = ["station-1", "station-2"]

        XCTAssertEqual(persistence.favoriteStationKeys, ["station-1", "station-2"])
    }

    func testContextPolicyAndActionReportsSurviveRelaunch() throws {
        let persistence = try makePersistence()
        let policy = ContextIntelligencePolicy(
            isEnabled: true,
            usesHealthSignals: true,
            usesWeather: true,
            allowsAutomaticCalendarChanges: true
        )
        let report = ContextActionReport(
            action: .offerCalendarDeferral,
            outcome: .accepted,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        persistence.contextIntelligencePolicy = policy
        persistence.contextActionReports = [report]

        XCTAssertEqual(persistence.contextIntelligencePolicy, policy)
        XCTAssertEqual(persistence.contextActionReports, [report])
    }

    func testVerifiedExecutionPersistsAndCompletesInsideDecisionBudget() throws {
        let persistence = try makePersistence()
        let store = ExecutionTrustStore(persistence: persistence)
        let now = Date()

        let proof = store.record(
            action: .stationSearch,
            intentKey: "search:fastest",
            resultKey: "station-1",
            status: .completed,
            evidence: [
                ExecutionEvidence(
                    source: .deterministicEngine,
                    reliability: 1,
                    observedAt: now,
                    maximumAge: 60
                ),
                ExecutionEvidence(
                    source: .deviceLocation,
                    reliability: 0.98,
                    observedAt: now,
                    maximumAge: 300
                ),
                ExecutionEvidence(
                    source: .stationDataset,
                    reliability: 0.94,
                    observedAt: now,
                    maximumAge: 86_400
                )
            ],
            deterministicChecks: ["location": true, "candidate": true],
            contextKeys: ["period:2", "cell:38.39:27.19"],
            startedAt: now,
            estimatedTimeSavedSeconds: 120
        )

        XCTAssertTrue(proof.verified)
        XCTAssertEqual(persistence.executionProofs.first?.id, proof.id)
        XCTAssertEqual(store.value.estimatedMinutesSaved, 2)
        XCTAssertLessThan(store.lastDecisionLatencyMilliseconds, 200)
    }

    func testFrictionTelemetryPersistsOutcomeAndRouteMilestones() throws {
        let persistence = try makePersistence()
        let store = FrictionTelemetryStore(persistence: persistence)
        let now = Date()

        store.record(.locationReady, at: now.addingTimeInterval(0.1))
        store.record(.stationSearchStarted, at: now.addingTimeInterval(0.15))
        store.record(.outcomeReady, at: now.addingTimeInterval(0.25))
        store.record(.routeStarted, at: now.addingTimeInterval(0.5))

        XCTAssertEqual(store.summary.completedJourneys, 1)
        XCTAssertEqual(persistence.frictionEvents.last?.kind, .routeStarted)
        XCTAssertNotNil(store.summary.medianOutcomeReadyMilliseconds)
        XCTAssertNotNil(store.summary.medianRouteStartMilliseconds)
        XCTAssertEqual(store.summary.noOutcomeRate, 0)
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
