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
    private let persistence: any AppPersistence
    private let messages: AppMessagePresenter
    private var reportCooldowns: [String: Date]

    private(set) var stations: [Station] = []
    private(set) var stationStatuses: [String: StationStatusSummary] = [:]
    private(set) var communityInsights: [String: StationCommunityInsight] = [:]
    private(set) var loadState: StationLoadState = .idle

    init(
        pipeline: StationDataPipeline,
        statusClient: any StatusClient,
        persistence: any AppPersistence,
        messages: AppMessagePresenter
    ) {
        self.pipeline = pipeline
        self.statusClient = statusClient
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

    func reloadStatuses(idToken: String? = nil) async {
        do {
            stationStatuses = try await pipeline.reloadStatuses(idToken: idToken)
        } catch {
            stationStatuses = [:]
            AppLogger.data.error("Station statuses failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func reloadCommunityData(idToken: String? = nil) async {
        async let statusesTask = pipeline.reloadStatuses(idToken: idToken)
        async let insightsTask = pipeline.reloadCommunityInsights(idToken: idToken)
        do {
            stationStatuses = try await statusesTask
        } catch {
            stationStatuses = [:]
            AppLogger.data.error("Station statuses failed: \(error.localizedDescription, privacy: .public)")
        }
        do {
            communityInsights = try await insightsTask
        } catch {
            communityInsights = [:]
            AppLogger.data.error("Station insights failed: \(error.localizedDescription, privacy: .public)")
        }
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
        guard auth.isAuthenticated else {
            messages.present(.localized(key: "service.report_login_required", kind: .error))
            return false
        }
        guard canReportStatus(for: stationKey) else {
            messages.present(.localized(
                key: "service.report_cooldown",
                replacements: ["seconds": "\(reportCooldownRemaining(for: stationKey))"],
                kind: .error
            ))
            return false
        }

        do {
            try await auth.authenticatedRequest { session in
                try await self.statusClient.sendStationReport(
                    stationKey: stationKey,
                    status: status,
                    comment: status,
                    uid: session.uid,
                    idToken: session.idToken
                )
            }
            reportCooldowns[stationKey] = Date()
            persistReportCooldowns()
            let session = try? await auth.validSession()
            await reloadStatuses(idToken: session?.idToken)
            messages.present(.localized(key: "service.report_sent", kind: .success))
            return true
        } catch {
            messages.present(.auth(AuthError.map(error)))
            return false
        }
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
        guard auth.isAuthenticated else {
            messages.present(.localized(key: "data_quality.login_required", kind: .error))
            return false
        }
        guard !contribution.values.isEmpty, canContribute(to: stationKey) else { return false }

        do {
            try await auth.authenticatedRequest { session in
                try await self.statusClient.sendStationContribution(
                    stationKey: stationKey,
                    contribution: contribution,
                    uid: session.uid,
                    idToken: session.idToken
                )
            }
            reportCooldowns["contribution:\(stationKey)"] = Date()
            persistReportCooldowns()
            let session = try? await auth.validSession()
            await reloadCommunityData(idToken: session?.idToken)
            messages.present(.localized(key: "data_quality.thanks", kind: .success))
            return true
        } catch {
            messages.present(.auth(AuthError.map(error)))
            return false
        }
    }

    private func refreshStations() async {
        do {
            guard let refreshed = try await pipeline.refreshStations() else { return }
            stations = refreshed
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
}
