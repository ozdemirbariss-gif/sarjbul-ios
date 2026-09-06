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
    private struct PendingEvaluation {
        var trigger: ChargingAgentTrigger
        var location: UserLocation
    }

    private let stationData: StationDataStore
    private let settings: UserSettingsStore
    private let search: SearchCoordinator
    private let persistence: any AppPersistence
    private let executionTrust: ExecutionTrustStore
    private let telemetryClient: any VehicleTelemetryClient
    private let notificationService: AutonomousChargingNotificationService
    private let decisionEngine = AutonomousChargingDecisionEngine()
    private let triggerEngine = TriggerActionEngine()
    private var evaluationInProgress = false
    private var pendingEvaluation: PendingEvaluation?

    private(set) var proposal: AutonomousChargingProposal?
    private(set) var state: AutonomousAgentState = .idle
    private(set) var lastDecisionReason: AutonomousChargingDecision.Reason?
    private(set) var reports: [AutomationReport]

    var latestReport: AutomationReport? { reports.first }
    var latestVehicleTelemetry: VehicleTelemetrySnapshot? { persistence.lastVehicleTelemetry }

    init(
        stationData: StationDataStore,
        settings: UserSettingsStore,
        search: SearchCoordinator,
        persistence: any AppPersistence,
        executionTrust: ExecutionTrustStore,
        telemetryClient: any VehicleTelemetryClient = ProfileVehicleTelemetryClient(),
        notificationService: AutonomousChargingNotificationService = AutonomousChargingNotificationService()
    ) {
        self.stationData = stationData
        self.settings = settings
        self.search = search
        self.persistence = persistence
        self.executionTrust = executionTrust
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

    func refreshInBackground() async -> Bool {
        defer { AutonomousBackgroundScheduler.scheduleAll() }
        return await runWorker(trigger: .backgroundRefresh, location: persistence.lastKnownLocation)
    }

    func processInBackground() async -> Bool {
        defer { AutonomousBackgroundScheduler.scheduleAll() }
        return await runWorker(trigger: .backgroundProcessing, location: persistence.lastKnownLocation)
    }

    func handleSilentPush() async -> Bool {
        return await runWorker(trigger: .silentPush, location: persistence.lastKnownLocation)
    }

    func evaluate(trigger: ChargingAgentTrigger, location: UserLocation?) async {
        _ = await runWorker(trigger: trigger, location: location)
    }

    private func runWorker(trigger: ChargingAgentTrigger, location: UserLocation?) async -> Bool {
        guard settings.autonomousChargingPolicy.isEnabled else { return true }
        guard let location else { return false }
        let request = PendingEvaluation(trigger: trigger, location: location)
        guard !evaluationInProgress else {
            pendingEvaluation = request
            return true
        }

        evaluationInProgress = true
        var nextRequest: PendingEvaluation? = request
        var result = true
        while let currentRequest = nextRequest {
            pendingEvaluation = nil
            state = .evaluating
            result = await performWorker(
                trigger: currentRequest.trigger,
                location: currentRequest.location
            )
            nextRequest = pendingEvaluation
        }
        evaluationInProgress = false
        state = proposal == nil ? .idle : .ready
        return result
    }

    private func performWorker(trigger: ChargingAgentTrigger, location: UserLocation) async -> Bool {
        guard settings.autonomousChargingPolicy.isEnabled else { return true }
        guard persistence.autonomousChargingMutedUntil.map({ $0 <= Date() }) ?? true else { return true }
        let now = Date()
        let maximumLocationAge: TimeInterval = location.source == .device ? 15 * 60 : 60 * 60
        guard location.isFresh(at: now, maximumAge: maximumLocationAge) else {
            lastDecisionReason = .staleLocation
            return false
        }

        guard let telemetry = await telemetryClient.latestSnapshot(fallbackProfile: settings.profile) else {
            lastDecisionReason = .staleTelemetry
            return false
        }
        persistence.lastVehicleTelemetry = telemetry

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
        guard stationData.isOperational else { return false }
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
            return true
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
            return true
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
        await applyDecision(
            decision,
            plan: plan,
            telemetry: telemetry,
            candidates: candidates,
            location: location,
            trigger: trigger,
            previousStationName: previousStationName,
            now: now
        )
        return true
    }

    private func applyDecision(
        _ decision: AutonomousChargingDecision,
        plan: AutomationPlan,
        telemetry: VehicleTelemetrySnapshot,
        candidates: [StationCandidate],
        location: UserLocation,
        trigger: ChargingAgentTrigger,
        previousStationName: String?,
        now: Date
    ) async {
        guard case .propose(let proposal) = decision else {
            if case .noAction(let reason) = decision { lastDecisionReason = reason }
            return
        }
        guard let selectedCandidate = candidates.first(where: {
            $0.station.statusKey == proposal.stationKey
        }) else {
            lastDecisionReason = .noSafeStation
            return
        }
        let evidence = proposalEvidence(
            telemetry: telemetry,
            candidate: selectedCandidate,
            location: location,
            now: now
        )
        let checks = [
            "arrival-safe": proposal.arrivalChargePercent >= settings.autonomousChargingPolicy.minimumArrivalPercent,
            "station-score": proposal.stationScore >= settings.autonomousChargingPolicy.minimumStationScore,
            "station-not-risky": !selectedCandidate.hasRiskyStatus,
            "proposal-fresh": proposal.expiresAt > now
        ]
        let trust = executionTrust.assess(
            action: .routePrepared,
            evidence: evidence,
            deterministicChecks: checks,
            now: now
        )
        guard trust.isVerified else {
            lastDecisionReason = .noSafeStation
            return
        }
        persistVerifiedProposal(
            proposal,
            plan: plan,
            evidence: evidence,
            checks: checks,
            location: location,
            trigger: trigger,
            previousStationName: previousStationName,
            now: now
        )
        guard shouldNotify(for: trigger) else { return }
        await notificationService.schedule(
            proposal: proposal,
            title: settings.t("agent.suggestion"),
            body: settings.t("agent.notification_body", [
                "station": ChargingSuggestionPresentation.stationName(proposal.stationName),
                "minutes": "\(proposal.estimatedMinutes)",
                "percent": "\(proposal.arrivalChargePercent)"
            ]),
            openRouteTitle: settings.t("agent.open_route"),
            snoozeTitle: settings.t("agent.snooze"),
            muteTodayTitle: settings.t("agent.mute_today")
        )
    }

    private func persistVerifiedProposal(
        _ proposal: AutonomousChargingProposal,
        plan: AutomationPlan,
        evidence: [ExecutionEvidence],
        checks: [String: Bool],
        location: UserLocation,
        trigger: ChargingAgentTrigger,
        previousStationName: String?,
        now: Date
    ) {
        lastDecisionReason = nil
        self.proposal = proposal
        persistence.autonomousChargingProposal = proposal
        persistence.lastAutonomousChargingProposal = proposal
        record(AutomationReport(
            rule: plan.rule,
            actions: plan.actions,
            previousStationName: previousStationName,
            selectedStationName: proposal.stationName,
            createdAt: now
        ))
        executionTrust.record(
            action: .routePrepared,
            intentKey: "autonomous:\(trigger.rawValue)",
            resultKey: proposal.stationKey,
            status: .completed,
            evidence: evidence,
            deterministicChecks: checks,
            contextKeys: executionTrust.contextKeys(
                location: location,
                preference: settings.filters.preference,
                date: now
            ),
            startedAt: now,
            completedAt: Date(),
            estimatedTimeSavedSeconds: 180
        )
    }

    private func shouldNotify(for trigger: ChargingAgentTrigger) -> Bool {
        trigger == .backgroundRefresh
            || trigger == .backgroundProcessing
            || trigger == .silentPush
            || trigger == .vehicleConnected
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

    private func proposalEvidence(
        telemetry: VehicleTelemetrySnapshot,
        candidate: StationCandidate,
        location: UserLocation,
        now: Date
    ) -> [ExecutionEvidence] {
        var evidence = [
            ExecutionEvidence(
                source: .deterministicEngine,
                reliability: 1,
                observedAt: now,
                maximumAge: 60
            ),
            ExecutionEvidence(
                source: .vehicleTelemetry,
                reliability: telemetry.isVehicleConnected ? 0.99 : 0.84,
                observedAt: telemetry.capturedAt,
                maximumAge: telemetry.isVehicleConnected ? 15 * 60 : 6 * 3_600
            ),
            ExecutionEvidence(
                source: location.source == .device ? .deviceLocation : .manualLocation,
                reliability: location.source == .device ? 0.98 : 0.90,
                observedAt: location.capturedAt,
                maximumAge: location.source == .device ? 300 : 86_400
            ),
            ExecutionEvidence(
                source: .stationDataset,
                reliability: candidate.station.confidenceScore,
                observedAt: executionTrust.stationObservedAt(candidate.station, fallback: now),
                maximumAge: 30 * 86_400
            )
        ]
        if let availability = candidate.liveAvailability {
            evidence.append(ExecutionEvidence(
                source: .realtimeAvailability,
                reliability: 0.98,
                observedAt: availability.updatedAt,
                maximumAge: 15 * 60
            ))
        }
        return evidence
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
        evaluationInProgress = false
        pendingEvaluation = nil
        persistence.autonomousChargingProposal = nil
        persistence.lastAutonomousChargingProposal = nil
        persistence.autonomousChargingMutedUntil = nil
        reports = []
        persistence.automationReports = []
    }
    #endif
}
