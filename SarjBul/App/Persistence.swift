import Foundation
import SarjBulCore

struct RecentStationRoute: Codable, Hashable, Identifiable {
    var stationID: String
    var stationKey: String
    var openedAt: Date

    var id: String { stationID }
}

@MainActor
protocol AppPersistence: AnyObject {
    var profile: DrivingProfile { get set }
    var authSession: FirebaseAuthSession? { get set }
    var language: AppLanguage { get set }
    var destination: JourneyDestination? { get set }
    var recentRoutes: [RecentStationRoute] { get set }
    var reportCooldowns: [String: Date] { get set }
    var loungeBestScore: Int { get set }
    var chargingSessions: [ChargingSessionRecord] { get set }
    var activeChargingSession: PersistedChargingSession? { get set }
    var demandAnalyticsEnabled: Bool { get set }
    var usageHabitEvents: [UsageHabitEvent] { get set }
    var habitSuggestionDismissals: [String: Date] { get set }
    var autonomousChargingPolicy: AutonomousChargingPolicy { get set }
    var autonomousChargingProposal: AutonomousChargingProposal? { get set }
    var lastAutonomousChargingProposal: AutonomousChargingProposal? { get set }
    var lastKnownLocation: UserLocation? { get set }
    var lastVehicleTelemetry: VehicleTelemetrySnapshot? { get set }
    var autonomousChargingMutedUntil: Date? { get set }
    var stationDataLastRefreshedAt: Date? { get set }
    var automationReports: [AutomationReport] { get set }
}

protocol SecureStorage {
    func data(for key: String) -> Data?
    func set(_ data: Data, for key: String)
    func remove(_ key: String)
}

private struct KeychainSecureStorage: SecureStorage {
    func data(for key: String) -> Data? { KeychainStore.data(for: key) }
    func set(_ data: Data, for key: String) { KeychainStore.set(data, for: key) }
    func remove(_ key: String) { KeychainStore.remove(key) }
}

@MainActor
final class SystemAppPersistence: AppPersistence {
    private enum Key {
        static let profile = "drivingProfile"
        static let authSession = "firebaseAuthSession"
        static let language = "appLanguage"
        static let destination = "journeyDestination"
        static let recentRoutes = "recentStationRoutes"
        static let reportCooldowns = "stationReportCooldowns"
        static let loungeBest = "voltDashBest"
        static let chargingSessions = "chargingSessions"
        static let activeChargingSession = "activeChargingSession"
        static let demandAnalyticsEnabled = "demandAnalyticsEnabled"
        static let usageHabitEvents = "usageHabitEvents"
        static let habitSuggestionDismissals = "habitSuggestionDismissals"
        static let autonomousChargingPolicy = "autonomousChargingPolicy"
        static let autonomousChargingProposal = "autonomousChargingProposal"
        static let lastAutonomousChargingProposal = "lastAutonomousChargingProposal"
        static let lastKnownLocation = "lastKnownLocation"
        static let lastVehicleTelemetry = "lastVehicleTelemetry"
        static let autonomousChargingMutedUntil = AutonomousNotificationConstants.mutedUntilKey
        static let stationDataLastRefreshedAt = "stationDataLastRefreshedAt"
        static let automationReports = "automationReports"
    }

    private let defaults: UserDefaults
    private let secureStorage: any SecureStorage
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        secureStorage: any SecureStorage = KeychainSecureStorage()
    ) {
        self.defaults = defaults
        self.secureStorage = secureStorage
    }

    var profile: DrivingProfile {
        get { decode(DrivingProfile.self, key: Key.profile) ?? DrivingProfile() }
        set { encode(newValue, key: Key.profile) }
    }

    var authSession: FirebaseAuthSession? {
        get {
            if let data = secureStorage.data(for: Key.authSession),
               let session = try? decoder.decode(FirebaseAuthSession.self, from: data) {
                return session
            }
            guard let legacyData = defaults.data(forKey: Key.authSession),
                  let session = try? decoder.decode(FirebaseAuthSession.self, from: legacyData) else {
                return nil
            }
            secureStorage.set(legacyData, for: Key.authSession)
            defaults.removeObject(forKey: Key.authSession)
            return session
        }
        set {
            defaults.removeObject(forKey: Key.authSession)
            guard let newValue, let data = try? encoder.encode(newValue) else {
                secureStorage.remove(Key.authSession)
                return
            }
            secureStorage.set(data, for: Key.authSession)
        }
    }

    var language: AppLanguage {
        get { AppLanguage(code: defaults.string(forKey: Key.language) ?? AppLanguage.tr.rawValue) }
        set { defaults.set(newValue.rawValue, forKey: Key.language) }
    }

    var destination: JourneyDestination? {
        get { decode(JourneyDestination.self, key: Key.destination) }
        set { encodeOptional(newValue, key: Key.destination) }
    }

    var recentRoutes: [RecentStationRoute] {
        get { decode([RecentStationRoute].self, key: Key.recentRoutes) ?? [] }
        set { encode(newValue, key: Key.recentRoutes) }
    }

    var reportCooldowns: [String: Date] {
        get { decode([String: Date].self, key: Key.reportCooldowns) ?? [:] }
        set { encode(newValue, key: Key.reportCooldowns) }
    }

    var loungeBestScore: Int {
        get { defaults.integer(forKey: Key.loungeBest) }
        set { defaults.set(newValue, forKey: Key.loungeBest) }
    }

    var chargingSessions: [ChargingSessionRecord] {
        get { decode([ChargingSessionRecord].self, key: Key.chargingSessions) ?? [] }
        set { encode(newValue, key: Key.chargingSessions) }
    }

    var activeChargingSession: PersistedChargingSession? {
        get { decode(PersistedChargingSession.self, key: Key.activeChargingSession) }
        set { encodeOptional(newValue, key: Key.activeChargingSession) }
    }

    var demandAnalyticsEnabled: Bool {
        get { defaults.bool(forKey: Key.demandAnalyticsEnabled) }
        set { defaults.set(newValue, forKey: Key.demandAnalyticsEnabled) }
    }

    var usageHabitEvents: [UsageHabitEvent] {
        get { decode([UsageHabitEvent].self, key: Key.usageHabitEvents) ?? [] }
        set { encode(newValue, key: Key.usageHabitEvents) }
    }

    var habitSuggestionDismissals: [String: Date] {
        get { decode([String: Date].self, key: Key.habitSuggestionDismissals) ?? [:] }
        set { encode(newValue, key: Key.habitSuggestionDismissals) }
    }

    var autonomousChargingPolicy: AutonomousChargingPolicy {
        get { decode(AutonomousChargingPolicy.self, key: Key.autonomousChargingPolicy) ?? AutonomousChargingPolicy() }
        set { encode(newValue, key: Key.autonomousChargingPolicy) }
    }

    var autonomousChargingProposal: AutonomousChargingProposal? {
        get { decode(AutonomousChargingProposal.self, key: Key.autonomousChargingProposal) }
        set { encodeOptional(newValue, key: Key.autonomousChargingProposal) }
    }

    var lastAutonomousChargingProposal: AutonomousChargingProposal? {
        get { decode(AutonomousChargingProposal.self, key: Key.lastAutonomousChargingProposal) }
        set { encodeOptional(newValue, key: Key.lastAutonomousChargingProposal) }
    }

    var lastKnownLocation: UserLocation? {
        get { decode(UserLocation.self, key: Key.lastKnownLocation) }
        set { encodeOptional(newValue, key: Key.lastKnownLocation) }
    }

    var lastVehicleTelemetry: VehicleTelemetrySnapshot? {
        get { decode(VehicleTelemetrySnapshot.self, key: Key.lastVehicleTelemetry) }
        set { encodeOptional(newValue, key: Key.lastVehicleTelemetry) }
    }

    var autonomousChargingMutedUntil: Date? {
        get { defaults.object(forKey: Key.autonomousChargingMutedUntil) as? Date }
        set { defaults.set(newValue, forKey: Key.autonomousChargingMutedUntil) }
    }

    var stationDataLastRefreshedAt: Date? {
        get { defaults.object(forKey: Key.stationDataLastRefreshedAt) as? Date }
        set { defaults.set(newValue, forKey: Key.stationDataLastRefreshedAt) }
    }

    var automationReports: [AutomationReport] {
        get { decode([AutomationReport].self, key: Key.automationReports) ?? [] }
        set { encode(Array(newValue.prefix(20)), key: Key.automationReports) }
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func encodeOptional<T: Encodable>(_ value: T?, key: String) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }
        encode(value, key: key)
    }
}
