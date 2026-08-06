import Foundation
import Observation
import SarjBulCore

enum AutonomousAgentState: Equatable {
    case idle
    case evaluating
    case ready
}

@MainActor
@Observable
final class AutonomousChargingAgentStore {
    private let stationData: StationDataStore
    private let settings: UserSettingsStore
    private let search: SearchCoordinator
    private let persistence: any AppPersistence
    private let telemetryClient: any VehicleTelemetryClient
    private let notificationService: AutonomousChargingNotificationService
    private let decisionEngine = AutonomousChargingDecisionEngine()

    private(set) var proposal: AutonomousChargingProposal?
    private(set) var state: AutonomousAgentState = .idle
    private(set) var lastDecisionReason: AutonomousChargingDecision.Reason?

    init(
        stationData: StationDataStore,
        settings: UserSettingsStore,
        search: SearchCoordinator,
        persistence: any AppPersistence,
        telemetryClient: any VehicleTelemetryClient = ProfileVehicleTelemetryClient(),
        notificationService: AutonomousChargingNotificationService = AutonomousChargingNotificationService()
    ) {
        self.stationData = stationData
        self.settings = settings
        self.search = search
        self.persistence = persistence
        self.telemetryClient = telemetryClient
        self.notificationService = notificationService
        if let saved = persistence.autonomousChargingProposal, saved.expiresAt > Date() {
            proposal = saved
            state = .ready
        } else {
            persistence.autonomousChargingProposal = nil
        }
    }

    func setEnabled(_ enabled: Bool) async {
        var policy = settings.autonomousChargingPolicy
        policy.isEnabled = enabled
        settings.autonomousChargingPolicy = policy
        if enabled {
            _ = await notificationService.requestAuthorization()
            AutonomousBackgroundScheduler.schedule()
            await evaluate(trigger: .appLaunch, location: search.userLocation ?? persistence.lastKnownLocation)
        } else {
            dismissProposal()
            AutonomousBackgroundScheduler.cancel()
        }
    }

    func updateLocation(_ location: UserLocation) async {
        persistence.lastKnownLocation = location
        await evaluate(trigger: .locationUpdate, location: location)
    }

    func refreshInBackground() async {
        defer { AutonomousBackgroundScheduler.schedule() }
        await evaluate(trigger: .backgroundRefresh, location: persistence.lastKnownLocation)
    }

    func evaluate(trigger: ChargingAgentTrigger, location: UserLocation?) async {
        guard settings.autonomousChargingPolicy.isEnabled, let location else { return }
        guard state != .evaluating else { return }
        state = .evaluating
        defer { if state == .evaluating { state = proposal == nil ? .idle : .ready } }

        guard let telemetry = await telemetryClient.latestSnapshot(fallbackProfile: settings.profile) else {
            lastDecisionReason = .staleTelemetry
            return
        }
        persistence.lastVehicleTelemetry = telemetry

        var filters = settings.filters
        filters.searchText = ""
        filters.rangeFilterEnabled = true
        let candidates = await stationData.candidates(
            origin: location,
            destination: nil,
            routePoints: [],
            profile: telemetry.drivingProfile,
            filters: filters,
            limit: 20
        )
        let decision = decisionEngine.evaluate(
            telemetry: telemetry,
            candidates: candidates,
            policy: settings.autonomousChargingPolicy,
            trigger: trigger,
            lastProposal: persistence.lastAutonomousChargingProposal
        )
        switch decision {
        case .noAction(let reason):
            lastDecisionReason = reason
        case .propose(let proposal):
            lastDecisionReason = nil
            self.proposal = proposal
            state = .ready
            persistence.autonomousChargingProposal = proposal
            persistence.lastAutonomousChargingProposal = proposal
            if trigger == .backgroundRefresh || trigger == .vehicleConnected {
                await notificationService.schedule(
                    proposal: proposal,
                    title: settings.t("agent.notification_title"),
                    body: settings.t("agent.notification_body", [
                        "station": proposal.stationName,
                        "minutes": "\(proposal.estimatedMinutes)"
                    ]),
                    actionTitle: settings.t("agent.open_route")
                )
            }
        }
    }

    func acceptProposal() async {
        guard let proposal else { return }
        if search.userLocation == nil, let savedLocation = persistence.lastKnownLocation {
            search.updateLocation(
                latitude: savedLocation.latitude,
                longitude: savedLocation.longitude,
                source: savedLocation.source
            )
        }
        await search.openStation(withKey: proposal.stationKey)
    }

    func openPendingRouteIfNeeded() async {
        guard let stationKey = PendingAutonomousRouteStore.consume() else { return }
        if search.userLocation == nil, let savedLocation = persistence.lastKnownLocation {
            search.updateLocation(
                latitude: savedLocation.latitude,
                longitude: savedLocation.longitude,
                source: savedLocation.source
            )
        }
        await search.openStation(withKey: stationKey)
    }

    func dismissProposal() {
        proposal = nil
        state = .idle
        persistence.autonomousChargingProposal = nil
    }

    #if DEBUG
    func resetForUITesting() {
        proposal = nil
        state = .idle
        persistence.autonomousChargingProposal = nil
        persistence.lastAutonomousChargingProposal = nil
    }
    #endif
}
