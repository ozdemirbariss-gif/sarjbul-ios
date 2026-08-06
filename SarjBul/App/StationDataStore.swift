import Foundation
import Observation
import SarjBulCore

enum StationLoadState: Sendable {
    case idle
    case loading
    case loaded
    case failed(AppMessage)
}

@MainActor
@Observable
final class StationDataStore {
    private static let reportCooldown: TimeInterval = 60
    private static let contributionCooldown: TimeInterval = 30

    private let pipeline: StationDataPipeline
    private let statusClient: any StatusClient
    private let realtimeClient: any RealtimeStationClient
    private let mutationQueue: AsyncMutationQueue
    private let persistence: any AppPersistence
    private let messages: AppMessagePresenter
    private var reportCooldowns: [String: Date]
    private var realtimeTask: Task<Void, Never>?

    var onRealtimeEvent: (@MainActor (StationRealtimeEvent) -> Void)?

    private(set) var stations: [Station] = []
    private(set) var stationStatuses: [String: StationStatusSummary] = [:]
    private(set) var communityInsights: [String: StationCommunityInsight] = [:]
    private(set) var loadState: StationLoadState = .idle

    init(
        pipeline: StationDataPipeline,
        statusClient: any StatusClient,
        realtimeClient: any RealtimeStationClient,
        mutationQueue: AsyncMutationQueue,
        persistence: any AppPersistence,
        messages: AppMessagePresenter
    ) {
        self.pipeline = pipeline
        self.statusClient = statusClient
        self.realtimeClient = realtimeClient
        self.mutationQueue = mutationQueue
        self.persistence = persistence
        self.messages = messages
        reportCooldowns = persistence.reportCooldowns
    }

    var canRetryLoad: Bool {
        if case .failed = loadState { return stations.isEmpty }
        return false
    }

    func load(statusIDToken: String? = nil) async {
        guard stations.isEmpty else { return }
        loadState = .loading
        do {
            stations = try await pipeline.loadStations()
            persistence.stationDataLastRefreshedAt = Date()
            loadState = .loaded
            await reloadCommunityData(idToken: statusIDToken)
            await refreshStations()
        } catch {
            let message = AppMessage.raw(error.localizedDescription, kind: .error)
            loadState = .failed(message)
            messages.present(message)
            AppLogger.data.error("Station load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func retry(statusIDToken: String? = nil) async {
        loadState = .idle
        await load(statusIDToken: statusIDToken)
    }

    @discardableResult
    func refreshForAutomation(idToken: String? = nil) async -> Bool {
        var didRefresh = false
        do {
            if let refreshed = try await pipeline.refreshStations() {
                stations = refreshed
                didRefresh = true
            }
            let didRefreshCommunity = await reloadCommunityData(idToken: idToken)
            if didRefresh || didRefreshCommunity {
                persistence.stationDataLastRefreshedAt = Date()
            }
            return didRefresh || didRefreshCommunity
        } catch {
            AppLogger.data.warning("Automation station refresh failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func reloadStatuses(idToken: String? = nil) async {
        do {
            stationStatuses = try await pipeline.reloadStatuses(idToken: idToken)
        } catch {
            AppLogger.data.error("Station statuses failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func startRealtime(idToken: String?) {
        realtimeTask?.cancel()
        realtimeTask = Task { [weak self, realtimeClient] in
            do {
                for try await event in realtimeClient.events(idToken: idToken) {
                    guard !Task.isCancelled, let self else { return }
                    await self.applyRealtime(event)
                }
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.data.warning("Realtime stream stopped: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func applyRealtime(_ event: StationRealtimeEvent) async {
        switch event {
        case .statusesSnapshot(let values): stationStatuses = values
        case .statusChanged(let key, let value): stationStatuses[key] = value
        case .insightsSnapshot(let values): communityInsights = values
        case .insightChanged(let key, let value): communityInsights[key] = value
        case .availabilitySnapshot, .availabilityChanged: break
        }
        await pipeline.applyRealtime(event)
        onRealtimeEvent?(event)
    }

    @discardableResult
    func reloadCommunityData(idToken: String? = nil) async -> Bool {
        async let statusesTask = pipeline.reloadStatuses(idToken: idToken)
        async let insightsTask = pipeline.reloadCommunityInsights(idToken: idToken)
        var didRefresh = false
        do {
            stationStatuses = try await statusesTask
            didRefresh = true
        } catch {
            AppLogger.data.error("Station statuses failed: \(error.localizedDescription, privacy: .public)")
        }
        do {
            communityInsights = try await insightsTask
            didRefresh = true
        } catch {
            AppLogger.data.error("Station insights failed: \(error.localizedDescription, privacy: .public)")
        }
        return didRefresh
    }

    func insight(for stationKey: String) -> StationCommunityInsight? {
        communityInsights[stationKey]
    }

    func candidates(
        origin: UserLocation,
        destination: JourneyDestination?,
        routePoints: [UserLocation],
        profile: DrivingProfile,
        filters: StationFilters,
        limit: Int = 80
    ) async -> [StationCandidate] {
        await pipeline.search(
            origin: origin,
            destination: destination,
            routePoints: routePoints,
            profile: profile,
            filters: filters,
            limit: limit
        )
    }

    func station(withKey key: String) async -> Station? {
        await pipeline.station(withKey: key)
    }

    func directCandidate(
        station: Station,
        origin: UserLocation,
        profile: DrivingProfile,
        filters: StationFilters
    ) async -> StationCandidate? {
        await pipeline.directCandidate(
            station: station,
            origin: origin,
            profile: profile,
            filters: filters
        )
    }

    func canReportStatus(for stationKey: String, now: Date = Date()) -> Bool {
        guard let lastReport = reportCooldowns[stationKey] else { return true }
        return now.timeIntervalSince(lastReport) >= Self.reportCooldown
    }

    func reportCooldownRemaining(for stationKey: String, now: Date = Date()) -> Int {
        guard let lastReport = reportCooldowns[stationKey] else { return 0 }
        return max(0, Int(ceil(Self.reportCooldown - now.timeIntervalSince(lastReport))))
    }

    func reportStatus(stationKey: String, status: String, auth: AuthStore) async -> Bool {
        guard canReportStatus(for: stationKey) else {
            messages.present(.localized(
                key: "service.report_cooldown",
                replacements: ["seconds": "\(reportCooldownRemaining(for: stationKey))"],
                kind: .error
            ))
            return false
        }

        let previous = stationStatuses[stationKey]
        let optimistic = Self.optimisticStatus(status)
        reportCooldowns[stationKey] = Date()
        persistReportCooldowns()
        await applyRealtime(.statusChanged(key: stationKey, value: optimistic))

        await mutationQueue.enqueue(id: "status:\(stationKey)") { [auth, statusClient] in
            try await auth.authenticatedRequest { session in
                try await statusClient.sendStationReport(
                    stationKey: stationKey,
                    status: status,
                    comment: status,
                    uid: session.uid,
                    idToken: session.idToken
                )
            }
        } completion: { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.messages.present(.localized(key: "service.report_sent", kind: .success))
            case .failure(let error):
                self.reportCooldowns[stationKey] = nil
                self.persistReportCooldowns()
                Task { await self.applyRealtime(.statusChanged(key: stationKey, value: previous)) }
                self.messages.present(.auth(AuthError.map(error)))
            }
        }
        return true
    }

    func canContribute(to stationKey: String, now: Date = Date()) -> Bool {
        guard let last = reportCooldowns["contribution:\(stationKey)"] else { return true }
        return now.timeIntervalSince(last) >= Self.contributionCooldown
    }

    func submitContribution(
        stationKey: String,
        contribution: StationContribution,
        auth: AuthStore
    ) async -> Bool {
        guard !contribution.values.isEmpty, canContribute(to: stationKey) else { return false }

        let cooldownKey = "contribution:\(stationKey)"
        reportCooldowns[cooldownKey] = Date()
        persistReportCooldowns()
        messages.present(.localized(key: "data_quality.thanks", kind: .success))

        await mutationQueue.enqueue(id: cooldownKey) { [auth, statusClient] in
            try await auth.authenticatedRequest { session in
                try await statusClient.sendStationContribution(
                    stationKey: stationKey,
                    contribution: contribution,
                    uid: session.uid,
                    idToken: session.idToken
                )
            }
        } completion: { [weak self] result in
            guard let self, case .failure(let error) = result else { return }
            self.reportCooldowns[cooldownKey] = nil
            self.persistReportCooldowns()
            self.messages.present(.auth(AuthError.map(error)))
        }
        return true
    }

    private func refreshStations() async {
        do {
            guard let refreshed = try await pipeline.refreshStations() else { return }
            stations = refreshed
            persistence.stationDataLastRefreshedAt = Date()
        } catch {
            AppLogger.data.warning("Remote station refresh skipped: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistReportCooldowns() {
        reportCooldowns = reportCooldowns.filter {
            Date().timeIntervalSince($0.value) < 24 * 60 * 60
        }
        persistence.reportCooldowns = reportCooldowns
    }

    private static func optimisticStatus(_ status: String) -> StationStatusSummary {
        let normalized = status.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "tr_TR")
        )
        let isAvailable = ["uygun", "bos", "sorunsuz", "aktif"].contains(where: normalized.contains)
        return StationStatusSummary(
            durum: isAvailable ? "aktif" : "riskli",
            etiket: status,
            toplam: 1
        )
    }
}
