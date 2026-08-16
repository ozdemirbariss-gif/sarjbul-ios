import Foundation
import Observation
import SarjBulCore

enum FrictionEventKind: String, Codable, Sendable {
    case appOpened
    case locationReady
    case stationSearchStarted
    case outcomeReady
    case noOutcome
    case locationPermissionDenied
    case navigationChoicePresented
    case navigationChoiceCompleted
    case navigationHandoffSucceeded
    case navigationHandoffFailed
    case recommendationCorrected
    case routeStarted
    case stationArrived
    case chargingStarted
    case chargingCompleted
}

struct FrictionEvent: Codable, Identifiable, Sendable {
    var id = UUID()
    var sessionID: UUID
    var kind: FrictionEventKind
    var occurredAt: Date
    var elapsedSinceLaunchMilliseconds: Int
    var journeyID: UUID?
}

struct ActiveRouteJourney: Codable, Sendable {
    var id: UUID
    var station: Station
    var startedAt: Date
    var arrivedAt: Date?
}

struct FrictionSummary: Sendable {
    var completedJourneys: Int
    var completedCharges: Int
    var medianOutcomeReadyMilliseconds: Int?
    var medianRouteStartMilliseconds: Int?
    var noOutcomeRate: Double
    var navigationHandoffRate: Double
    var routeToChargeRate: Double
}

@MainActor
@Observable
final class FrictionTelemetryStore {
    private let persistence: any AppPersistence
    private let sessionID = UUID()
    private let launchedAt = Date()
    private var recordedKinds = Set<FrictionEventKind>()

    private(set) var events: [FrictionEvent]
    private(set) var activeJourney: ActiveRouteJourney?

    init(persistence: any AppPersistence) {
        self.persistence = persistence
        events = persistence.frictionEvents
        activeJourney = persistence.activeRouteJourney
        if let activeJourney, Date().timeIntervalSince(activeJourney.startedAt) > 8 * 60 * 60 {
            self.activeJourney = nil
            persistence.activeRouteJourney = nil
        }
        record(.appOpened)
    }

    func record(
        _ kind: FrictionEventKind,
        oncePerSession: Bool = true,
        journeyID: UUID? = nil,
        at date: Date = Date()
    ) {
        if oncePerSession, recordedKinds.contains(kind) { return }
        recordedKinds.insert(kind)
        events.append(FrictionEvent(
            sessionID: sessionID,
            kind: kind,
            occurredAt: date,
            elapsedSinceLaunchMilliseconds: max(0, Int(date.timeIntervalSince(launchedAt) * 1_000)),
            journeyID: journeyID
        ))
        events = Array(events.suffix(240))
        persistence.frictionEvents = events
    }

    func navigationChoicePresented() {
        record(.navigationChoicePresented)
    }

    func navigationChoiceCompleted() {
        record(.navigationChoiceCompleted)
    }

    func navigationHandoff(succeeded: Bool, station: Station, correctedRecommendation: Bool) {
        guard succeeded else {
            record(.navigationHandoffFailed, oncePerSession: false)
            return
        }
        let journey = ActiveRouteJourney(id: UUID(), station: station, startedAt: Date())
        activeJourney = journey
        persistence.activeRouteJourney = journey
        record(.navigationHandoffSucceeded, oncePerSession: false, journeyID: journey.id)
        record(.routeStarted, oncePerSession: false, journeyID: journey.id)
        if correctedRecommendation {
            record(.recommendationCorrected, oncePerSession: false, journeyID: journey.id)
        }
    }

    func observeLocation(_ location: UserLocation) {
        guard var journey = activeJourney, journey.arrivedAt == nil else { return }
        let distance = DistanceCalculator.haversineKm(
            from: location,
            toLatitude: journey.station.latitude,
            longitude: journey.station.longitude
        )
        guard distance <= 0.25 else { return }
        journey.arrivedAt = Date()
        activeJourney = journey
        persistence.activeRouteJourney = journey
        record(.stationArrived, oncePerSession: false, journeyID: journey.id)
    }

    func chargingStarted(at station: Station) {
        let journeyID = activeJourney?.station.statusKey == station.statusKey ? activeJourney?.id : nil
        record(.chargingStarted, oncePerSession: false, journeyID: journeyID)
    }

    func chargingCompleted() {
        let journeyID = activeJourney.flatMap { journey in
            events.contains { $0.kind == .chargingStarted && $0.journeyID == journey.id }
                ? journey.id
                : nil
        }
        record(.chargingCompleted, oncePerSession: false, journeyID: journeyID)
        if journeyID != nil {
            activeJourney = nil
            persistence.activeRouteJourney = nil
        }
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
        let handoffs = events.filter {
            $0.kind == .navigationHandoffSucceeded || $0.kind == .navigationHandoffFailed
        }
        let successfulHandoffs = handoffs.filter { $0.kind == .navigationHandoffSucceeded }.count
        let routeJourneys = Set(events.filter { $0.kind == .routeStarted }.compactMap(\.journeyID))
        let chargedJourneys = Set(events.filter { $0.kind == .chargingStarted }.compactMap(\.journeyID))
        return FrictionSummary(
            completedJourneys: routeTimes.count,
            completedCharges: events.filter { $0.kind == .chargingCompleted }.count,
            medianOutcomeReadyMilliseconds: median(outcomeTimes),
            medianRouteStartMilliseconds: median(routeTimes),
            noOutcomeRate: searches == 0 ? 0 : Double(failures) / Double(searches),
            navigationHandoffRate: handoffs.isEmpty ? 0 : Double(successfulHandoffs) / Double(handoffs.count),
            routeToChargeRate: routeJourneys.isEmpty
                ? 0
                : Double(routeJourneys.intersection(chargedJourneys).count) / Double(routeJourneys.count)
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
