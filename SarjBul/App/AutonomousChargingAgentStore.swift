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
    private let triggerEngine = TriggerActionEngine()

    private(set) var proposal: AutonomousChargingProposal?
    private(set) var state: AutonomousAgentState = .idle
    private(set) var lastDecisionReason: AutonomousChargingDecision.Reason?
    private(set) var reports: [AutomationReport]

    var latestReport: AutomationReport? { reports.first }

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
        reports = persistence.automationReports
        if let mutedUntil = persistence.autonomousChargingMutedUntil, mutedUntil > Date() {
            persistence.autonomousChargingProposal = nil
        } else if let saved = persistence.autonomousChargingProposal, saved.expiresAt > Date() {
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
        defer { AutonomousBackgroundScheduler.scheduleAll() }
        await runWorker(trigger: .backgroundRefresh, location: persistence.lastKnownLocation)
    }

    func processInBackground() async {
        defer { AutonomousBackgroundScheduler.scheduleAll() }
        await runWorker(trigger: .backgroundProcessing, location: persistence.lastKnownLocation)
    }

    func handleSilentPush() async {
        await runWorker(trigger: .silentPush, location: persistence.lastKnownLocation)
    }

    func evaluate(trigger: ChargingAgentTrigger, location: UserLocation?) async {
        await runWorker(trigger: trigger, location: location)
    }

    private func runWorker(trigger: ChargingAgentTrigger, location: UserLocation?) async {
        guard settings.autonomousChargingPolicy.isEnabled, let location else { return }
        guard persistence.autonomousChargingMutedUntil.map({ $0 <= Date() }) ?? true else { return }
        guard state != .evaluating else { return }
        state = .evaluating
        defer { if state == .evaluating { state = proposal == nil ? .idle : .ready } }

        guard let telemetry = await telemetryClient.latestSnapshot(fallbackProfile: settings.profile) else {
            lastDecisionReason = .staleTelemetry
            return
        }
        persistence.lastVehicleTelemetry = telemetry

        let now = Date()
        var filters = settings.filters
        filters.searchText = ""
        filters.rangeFilterEnabled = true
        var candidates = await stationData.candidates(
            origin: location,
            destination: nil,
            routePoints: [],
            profile: telemetry.drivingProfile,
            filters: filters,
            limit: 20
        )
        let currentProposal = proposal ?? persistence.autonomousChargingProposal
        let currentCandidate = await candidate(
            for: currentProposal,
            among: candidates,
            origin: location,
            profile: telemetry.drivingProfile,
            filters: filters
        )
        let stationDataAge = persistence.stationDataLastRefreshedAt.map { now.timeIntervalSince($0) }
        let snapshot = AutomationSnapshot(
            isEnabled: settings.autonomousChargingPolicy.isEnabled,
            chargePercent: telemetry.chargePercent,
            triggerChargePercent: settings.autonomousChargingPolicy.triggerChargePercent,
            stationDataAge: stationDataAge,
            hasPreparedRoute: currentProposal != nil,
            preparedRouteIsRisky: currentProposal != nil && (currentCandidate?.hasRiskyStatus ?? true),
            preparedRouteIsExpired: currentProposal.map { $0.expiresAt <= now } ?? false
        )
        guard let plan = triggerEngine.plan(for: snapshot) else {
            lastDecisionReason = telemetry.chargePercent > settings.autonomousChargingPolicy.triggerChargePercent
                ? .chargeSufficient
                : .cooldownActive
            return
        }

        if plan.actions.contains(.refreshStationData) {
            _ = await stationData.refreshForAutomation()
            candidates = await stationData.candidates(
                origin: location,
                destination: nil,
                routePoints: [],
                profile: telemetry.drivingProfile,
                filters: filters,
                limit: 20
            )
        }

        let routeAction = plan.actions.first {
            $0 == .prepareChargingRoute || $0 == .replacePreparedRoute
        }
        guard routeAction != nil else {
            record(AutomationReport(rule: plan.rule, actions: plan.actions, createdAt: now))
            lastDecisionReason = nil
            return
        }

        let previousStationName = currentProposal?.stationName
        let respectsCooldown = routeAction == .prepareChargingRoute && plan.rule == .lowCharge
        let decision = decisionEngine.evaluate(
            telemetry: telemetry,
            candidates: candidates,
            policy: settings.autonomousChargingPolicy,
            trigger: trigger,
            lastProposal: respectsCooldown ? persistence.lastAutonomousChargingProposal : nil,
            now: now
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
            record(AutomationReport(
                rule: plan.rule,
                actions: plan.actions,
                previousStationName: previousStationName,
                selectedStationName: proposal.stationName,
                createdAt: now
            ))
            if trigger == .backgroundRefresh
                || trigger == .backgroundProcessing
                || trigger == .silentPush
                || trigger == .vehicleConnected {
                await notificationService.schedule(
                    proposal: proposal,
                    title: settings.t("agent.optimized_notification_title"),
                    body: settings.t("agent.optimized_notification_body", [
                        "station": proposal.stationName,
                        "minutes": "\(proposal.estimatedMinutes)"
                    ]),
                    openRouteTitle: settings.t("agent.open_route"),
                    snoozeTitle: settings.t("agent.snooze"),
                    muteTodayTitle: settings.t("agent.mute_today")
                )
            }
        }
    }

    private func candidate(
        for proposal: AutonomousChargingProposal?,
        among candidates: [StationCandidate],
        origin: UserLocation,
        profile: DrivingProfile,
        filters: StationFilters
    ) async -> StationCandidate? {
        guard let proposal else { return nil }
        if let candidate = candidates.first(where: { $0.station.statusKey == proposal.stationKey }) {
            return candidate
        }
        guard let station = await stationData.station(withKey: proposal.stationKey) else { return nil }
        return await stationData.directCandidate(
            station: station,
            origin: origin,
            profile: profile,
            filters: filters
        )
    }

    private func record(_ report: AutomationReport) {
        reports.insert(report, at: 0)
        reports = Array(reports.prefix(20))
        persistence.automationReports = reports
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

    func handleMutedNotificationAction() {
        dismissProposal()
    }

    #if DEBUG
    func resetForUITesting() {
        proposal = nil
        state = .idle
        persistence.autonomousChargingProposal = nil
        persistence.lastAutonomousChargingProposal = nil
        persistence.autonomousChargingMutedUntil = nil
        reports = []
        persistence.automationReports = []
    }
    #endif
}
