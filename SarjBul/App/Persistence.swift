import Foundation
import SarjBulCore

struct RecentStationRoute: Codable, Hashable, Identifiable {
    var stationID: String
    var stationKey: String
    var openedAt: Date

    var id: String { stationID }
}

enum OfflineMutationPayload: Codable, Sendable {
    case favorite(stationKey: String, isFavorite: Bool)
    case stationReport(stationKey: String, status: String)
    case contribution(stationKey: String, contribution: StationContribution)
    case demand(SearchDemandEvent)
}

struct PendingOfflineMutation: Codable, Identifiable, Sendable {
    var id: String
    var deduplicationKey: String
    var payload: OfflineMutationPayload
    var createdAt: Date
}

struct ImplicitFeedbackEvent: Codable, Identifiable, Sendable {
    var id = UUID()
    var signal: ImplicitFeedbackSignal
    var features: StationPreferenceVector
    var actionLatency: TimeInterval
    var occurredAt: Date
}

@MainActor
protocol AppPersistence: AnyObject {
    var profile: DrivingProfile { get set }
    var authSession: FirebaseAuthSession? { get set }
    var language: AppLanguage { get set }
    var destination: JourneyDestination? { get set }
    var recentRoutes: [RecentStationRoute] { get set }
    var favoriteStationKeys: Set<String> { get set }
    var reportCooldowns: [String: Date] { get set }
    var loungeBestScore: Int { get set }
    var chargingSessions: [ChargingSessionRecord] { get set }
    var activeChargingSession: PersistedChargingSession? { get set }
    var demandAnalyticsEnabled: Bool { get set }
    var usageHabitEvents: [UsageHabitEvent] { get set }
    var habitSuggestionDismissals: [String: Date] { get set }
    var implicitUserProfile: ImplicitUserProfile { get set }
    var implicitFeedbackEvents: [ImplicitFeedbackEvent] { get set }
    var contextIntelligencePolicy: ContextIntelligencePolicy { get set }
    var contextActionReports: [ContextActionReport] { get set }
    var autonomousChargingPolicy: AutonomousChargingPolicy { get set }
    var autonomousChargingProposal: AutonomousChargingProposal? { get set }
    var lastAutonomousChargingProposal: AutonomousChargingProposal? { get set }
    var lastKnownLocation: UserLocation? { get set }
    var lastVehicleTelemetry: VehicleTelemetrySnapshot? { get set }
    var autonomousChargingMutedUntil: Date? { get set }
    var stationDataLastRefreshedAt: Date? { get set }
    var cachedStationStatuses: [String: StationStatusSummary] { get set }
    var cachedCommunityInsights: [String: StationCommunityInsight] { get set }
    var automationReports: [AutomationReport] { get set }
    var pendingOfflineMutations: [PendingOfflineMutation] { get set }
    var executionProofs: [ExecutionProof] { get set }
    var contextualRelationGraph: ContextualRelationGraph { get set }
    var frictionEvents: [FrictionEvent] { get set }
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
        static let favoriteStationKeys = "favoriteStationKeys"
        static let reportCooldowns = "stationReportCooldowns"
        static let loungeBest = "voltDashBest"
        static let chargingSessions = "chargingSessions"
        static let activeChargingSession = "activeChargingSession"
        static let demandAnalyticsEnabled = "demandAnalyticsEnabled"
        static let usageHabitEvents = "usageHabitEvents"
        static let habitSuggestionDismissals = "habitSuggestionDismissals"
        static let implicitUserProfile = "implicitUserProfile"
        static let implicitFeedbackEvents = "implicitFeedbackEvents"
        static let contextIntelligencePolicy = "contextIntelligencePolicy"
        static let contextActionReports = "contextActionReports"
        static let autonomousChargingPolicy = "autonomousChargingPolicy"
        static let autonomousChargingProposal = "autonomousChargingProposal"
        static let lastAutonomousChargingProposal = "lastAutonomousChargingProposal"
        static let lastKnownLocation = "lastKnownLocation"
        static let lastVehicleTelemetry = "lastVehicleTelemetry"
        static let autonomousChargingMutedUntil = AutonomousNotificationConstants.mutedUntilKey
        static let stationDataLastRefreshedAt = "stationDataLastRefreshedAt"
        static let cachedStationStatuses = "cachedStationStatuses"
        static let cachedCommunityInsights = "cachedCommunityInsights"
        static let automationReports = "automationReports"
        static let pendingOfflineMutations = "pendingOfflineMutations"
        static let executionProofs = "executionProofs"
        static let contextualRelationGraph = "contextualRelationGraph"
        static let frictionEvents = "frictionEvents"
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

    var favoriteStationKeys: Set<String> {
        get { Set(decode([String].self, key: Key.favoriteStationKeys) ?? []) }
        set { encode(Array(newValue).sorted(), key: Key.favoriteStationKeys) }
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

    var implicitUserProfile: ImplicitUserProfile {
        get { decode(ImplicitUserProfile.self, key: Key.implicitUserProfile) ?? ImplicitUserProfile() }
        set { encode(newValue, key: Key.implicitUserProfile) }
    }

    var implicitFeedbackEvents: [ImplicitFeedbackEvent] {
        get { decode([ImplicitFeedbackEvent].self, key: Key.implicitFeedbackEvents) ?? [] }
        set { encode(Array(newValue.suffix(120)), key: Key.implicitFeedbackEvents) }
    }

    var contextIntelligencePolicy: ContextIntelligencePolicy {
        get { decode(ContextIntelligencePolicy.self, key: Key.contextIntelligencePolicy) ?? ContextIntelligencePolicy() }
        set { encode(newValue, key: Key.contextIntelligencePolicy) }
    }

    var contextActionReports: [ContextActionReport] {
        get { decode([ContextActionReport].self, key: Key.contextActionReports) ?? [] }
        set { encode(Array(newValue.prefix(40)), key: Key.contextActionReports) }
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

    var cachedStationStatuses: [String: StationStatusSummary] {
        get { decode([String: StationStatusSummary].self, key: Key.cachedStationStatuses) ?? [:] }
        set { encode(newValue, key: Key.cachedStationStatuses) }
    }

    var cachedCommunityInsights: [String: StationCommunityInsight] {
        get { decode([String: StationCommunityInsight].self, key: Key.cachedCommunityInsights) ?? [:] }
        set { encode(newValue, key: Key.cachedCommunityInsights) }
    }

    var pendingOfflineMutations: [PendingOfflineMutation] {
        get {
            if let data = secureStorage.data(for: Key.pendingOfflineMutations),
               let mutations = try? decoder.decode([PendingOfflineMutation].self, from: data) {
                return mutations
            }
            guard let legacy = defaults.data(forKey: Key.pendingOfflineMutations),
                  let mutations = try? decoder.decode([PendingOfflineMutation].self, from: legacy) else {
                return []
            }
            secureStorage.set(legacy, for: Key.pendingOfflineMutations)
            defaults.removeObject(forKey: Key.pendingOfflineMutations)
            return mutations
        }
        set {
            defaults.removeObject(forKey: Key.pendingOfflineMutations)
            let bounded = Array(newValue.suffix(100))
            guard !bounded.isEmpty, let data = try? encoder.encode(bounded) else {
                secureStorage.remove(Key.pendingOfflineMutations)
                return
            }
            secureStorage.set(data, for: Key.pendingOfflineMutations)
        }
    }

    var executionProofs: [ExecutionProof] {
        get { decode([ExecutionProof].self, key: Key.executionProofs) ?? [] }
        set { encode(Array(newValue.prefix(200)), key: Key.executionProofs) }
    }

    var contextualRelationGraph: ContextualRelationGraph {
        get { decode(ContextualRelationGraph.self, key: Key.contextualRelationGraph) ?? ContextualRelationGraph() }
        set { encode(newValue, key: Key.contextualRelationGraph) }
    }

    var frictionEvents: [FrictionEvent] {
        get { decode([FrictionEvent].self, key: Key.frictionEvents) ?? [] }
        set { encode(Array(newValue.suffix(240)), key: Key.frictionEvents) }
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
