import Foundation
import Observation
import SarjBulCore

struct UsageHabitEvent: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case search
        case routeOpened
    }

    var id = UUID()
    var kind: Kind
    var occurredAt: Date
    var preference: String?
    var stationKey: String?
    var stationName: String?
    var searchParameters: SearchIntentParameters? = nil
}

enum HabitDayPeriod: String, Codable, Hashable {
    case morning
    case afternoon
    case evening
    case night

    static func period(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> HabitDayPeriod {
        switch calendar.component(.hour, from: date) {
        case 5..<12: .morning
        case 12..<17: .afternoon
        case 17..<22: .evening
        default: .night
        }
    }
}

enum HabitSuggestion: Hashable, Identifiable {
    case repeatedStation(stationKey: String, stationName: String, period: HabitDayPeriod)
    case routePreference(preference: RoutePreference, period: HabitDayPeriod)

    var id: String {
        switch self {
        case .repeatedStation(let stationKey, _, let period):
            "station:\(stationKey):\(period.rawValue)"
        case .routePreference(let preference, let period):
            "preference:\(preference.rawValue):\(period.rawValue)"
        }
    }
}

@MainActor
@Observable
final class HabitStore {
    private static let retentionDays = 90
    private static let dismissalDays = 14
    private let persistence: any AppPersistence
    private(set) var events: [UsageHabitEvent]
    private var dismissals: [String: Date]

    init(persistence: any AppPersistence) {
        self.persistence = persistence
        events = persistence.usageHabitEvents
        dismissals = persistence.habitSuggestionDismissals
        prune(now: Date())
    }

    func recordSearch(preference: RoutePreference, at date: Date = Date()) {
        guard shouldRecord(kind: .search, value: preference.rawValue, at: date, cooldownHours: 2) else { return }
        append(UsageHabitEvent(
            kind: .search,
            occurredAt: date,
            preference: preference.rawValue
        ), now: date)
    }

    func recordSearch(filters: StationFilters, at date: Date = Date()) {
        let parameters = SearchIntentParameters(filters: filters)
        guard shouldRecord(
            kind: .search,
            value: persistenceKey(for: parameters),
            at: date,
            cooldownHours: 2
        ) else { return }
        append(UsageHabitEvent(
            kind: .search,
            occurredAt: date,
            preference: filters.preference.rawValue,
            searchParameters: parameters
        ), now: date)
    }

    func recordRouteOpened(_ station: Station, at date: Date = Date()) {
        guard shouldRecord(kind: .routeOpened, value: station.statusKey, at: date, cooldownHours: 6) else { return }
        append(UsageHabitEvent(
            kind: .routeOpened,
            occurredAt: date,
            stationKey: station.statusKey,
            stationName: station.name
        ), now: date)
    }

    func suggestion(at now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> HabitSuggestion? {
        let period = HabitDayPeriod.period(for: now, calendar: calendar)
        let recent = events.filter {
            now.timeIntervalSince($0.occurredAt) <= Double(Self.retentionDays) * 86_400
                && HabitDayPeriod.period(for: $0.occurredAt, calendar: calendar) == period
        }

        if let stationSuggestion = repeatedStationSuggestion(from: recent, period: period, calendar: calendar),
           isAvailable(stationSuggestion, at: now) {
            return stationSuggestion
        }
        if let preferenceSuggestion = preferenceSuggestion(from: recent, period: period, calendar: calendar),
           isAvailable(preferenceSuggestion, at: now) {
            return preferenceSuggestion
        }
        return nil
    }

    func searchPrediction(
        at now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> SearchIntentPrediction? {
        let observations = events.compactMap { event -> SearchIntentObservation? in
            guard event.kind == .search, let parameters = event.searchParameters else { return nil }
            return SearchIntentObservation(
                occurredAt: event.occurredAt,
                contextKey: contextKey(for: event.occurredAt, calendar: calendar),
                parameters: parameters
            )
        }
        return PredictiveIntentEngine.predictSearch(
            observations: observations,
            contextKey: contextKey(for: now, calendar: calendar),
            now: now,
            calendar: calendar
        )
    }

    func dismiss(_ suggestion: HabitSuggestion, at date: Date = Date()) {
        dismissals[suggestion.id] = date
        persistence.habitSuggestionDismissals = dismissals
    }

    private func repeatedStationSuggestion(
        from events: [UsageHabitEvent],
        period: HabitDayPeriod,
        calendar: Calendar
    ) -> HabitSuggestion? {
        let routeEvents = events.filter { $0.kind == .routeOpened && $0.stationKey != nil }
        let grouped = Dictionary(grouping: routeEvents, by: { $0.stationKey ?? "" })
        let match = grouped.values
            .filter { distinctDayCount($0, calendar: calendar) >= 3 }
            .max { $0.count < $1.count }
        guard let match, let event = match.max(by: { $0.occurredAt < $1.occurredAt }),
              let stationKey = event.stationKey, let stationName = event.stationName else { return nil }
        return .repeatedStation(stationKey: stationKey, stationName: stationName, period: period)
    }

    private func preferenceSuggestion(
        from events: [UsageHabitEvent],
        period: HabitDayPeriod,
        calendar: Calendar
    ) -> HabitSuggestion? {
        let searchEvents = events.filter { $0.kind == .search && $0.preference != nil }
        guard distinctDayCount(searchEvents, calendar: calendar) >= 3, searchEvents.count >= 4 else { return nil }
        let grouped = Dictionary(grouping: searchEvents, by: { $0.preference ?? "" })
        guard let match = grouped.max(by: { $0.value.count < $1.value.count }),
              Double(match.value.count) / Double(searchEvents.count) >= 0.7,
              let preference = RoutePreference(rawValue: match.key) else { return nil }
        return .routePreference(preference: preference, period: period)
    }

    private func distinctDayCount(_ events: [UsageHabitEvent], calendar: Calendar) -> Int {
        Set(events.map { calendar.startOfDay(for: $0.occurredAt) }).count
    }

    private func isAvailable(_ suggestion: HabitSuggestion, at now: Date) -> Bool {
        guard let dismissedAt = dismissals[suggestion.id] else { return true }
        return now.timeIntervalSince(dismissedAt) >= Double(Self.dismissalDays) * 86_400
    }

    private func shouldRecord(
        kind: UsageHabitEvent.Kind,
        value: String,
        at date: Date,
        cooldownHours: Double
    ) -> Bool {
        !events.contains { event in
            let eventValue: String?
            if kind == .search, let parameters = event.searchParameters {
                eventValue = persistenceKey(for: parameters)
            } else {
                eventValue = kind == .search ? event.preference : event.stationKey
            }
            return event.kind == kind
                && eventValue == value
                && abs(date.timeIntervalSince(event.occurredAt)) < cooldownHours * 3_600
        }
    }

    private func contextKey(for date: Date, calendar: Calendar) -> String {
        let dayKind = calendar.isDateInWeekend(date) ? "weekend" : "weekday"
        return "\(dayKind):\(HabitDayPeriod.period(for: date, calendar: calendar).rawValue)"
    }

    private func persistenceKey(for parameters: SearchIntentParameters) -> String {
        [
            parameters.preference.rawValue,
            String(Int(parameters.minimumPowerKW.rounded())),
            parameters.socketFilters.sorted().joined(separator: ","),
            parameters.operatorFilters.sorted().joined(separator: ","),
            parameters.rangeFilterEnabled ? "range" : "all"
        ].joined(separator: "|")
    }

    private func append(_ event: UsageHabitEvent, now: Date) {
        events.append(event)
        prune(now: now)
        persistence.usageHabitEvents = events
    }

    private func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-Double(Self.retentionDays) * 86_400)
        events = Array(events.filter { $0.occurredAt >= cutoff }.suffix(240))
        dismissals = dismissals.filter { $0.value >= cutoff }
        persistence.usageHabitEvents = events
        persistence.habitSuggestionDismissals = dismissals
    }
}
