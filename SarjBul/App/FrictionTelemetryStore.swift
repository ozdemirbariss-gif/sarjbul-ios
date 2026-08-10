import Foundation
import Observation

enum FrictionEventKind: String, Codable, Sendable {
    case appOpened
    case locationReady
    case stationSearchStarted
    case outcomeReady
    case noOutcome
    case routeStarted
}

struct FrictionEvent: Codable, Identifiable, Sendable {
    var id = UUID()
    var sessionID: UUID
    var kind: FrictionEventKind
    var occurredAt: Date
    var elapsedSinceLaunchMilliseconds: Int
}

struct FrictionSummary: Sendable {
    var completedJourneys: Int
    var medianOutcomeReadyMilliseconds: Int?
    var medianRouteStartMilliseconds: Int?
    var noOutcomeRate: Double
}

@MainActor
@Observable
final class FrictionTelemetryStore {
    private let persistence: any AppPersistence
    private let sessionID = UUID()
    private let launchedAt = Date()
    private var recordedKinds = Set<FrictionEventKind>()

    private(set) var events: [FrictionEvent]

    init(persistence: any AppPersistence) {
        self.persistence = persistence
        events = persistence.frictionEvents
        record(.appOpened)
    }

    func record(_ kind: FrictionEventKind, oncePerSession: Bool = true, at date: Date = Date()) {
        if oncePerSession, recordedKinds.contains(kind) { return }
        recordedKinds.insert(kind)
        events.append(FrictionEvent(
            sessionID: sessionID,
            kind: kind,
            occurredAt: date,
            elapsedSinceLaunchMilliseconds: max(0, Int(date.timeIntervalSince(launchedAt) * 1_000))
        ))
        events = Array(events.suffix(240))
        persistence.frictionEvents = events
    }

    var summary: FrictionSummary {
        let sessions = Dictionary(grouping: events, by: \.sessionID)
        let outcomeTimes = sessions.values.compactMap { session in
            session.first(where: { $0.kind == .outcomeReady })?.elapsedSinceLaunchMilliseconds
        }
        let routeTimes = sessions.values.compactMap { session in
            session.first(where: { $0.kind == .routeStarted })?.elapsedSinceLaunchMilliseconds
        }
        let searches = events.filter { $0.kind == .stationSearchStarted }.count
        let failures = events.filter { $0.kind == .noOutcome }.count
        return FrictionSummary(
            completedJourneys: routeTimes.count,
            medianOutcomeReadyMilliseconds: median(outcomeTimes),
            medianRouteStartMilliseconds: median(routeTimes),
            noOutcomeRate: searches == 0 ? 0 : Double(failures) / Double(searches)
        )
    }

    private func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
