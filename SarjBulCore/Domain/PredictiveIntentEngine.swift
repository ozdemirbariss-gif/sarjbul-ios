import Foundation

public struct SearchIntentParameters: Codable, Hashable, Sendable {
    public var preference: RoutePreference
    public var minimumPowerKW: Double
    public var socketFilters: Set<String>
    public var operatorFilters: Set<String>
    public var rangeFilterEnabled: Bool

    public init(
        preference: RoutePreference,
        minimumPowerKW: Double,
        socketFilters: Set<String>,
        operatorFilters: Set<String>,
        rangeFilterEnabled: Bool
    ) {
        self.preference = preference
        self.minimumPowerKW = minimumPowerKW
        self.socketFilters = socketFilters
        self.operatorFilters = operatorFilters
        self.rangeFilterEnabled = rangeFilterEnabled
    }

    public init(filters: StationFilters) {
        self.init(
            preference: filters.preference,
            minimumPowerKW: filters.minimumPowerKW,
            socketFilters: filters.socketFilters,
            operatorFilters: filters.operatorFilters,
            rangeFilterEnabled: filters.rangeFilterEnabled
        )
    }

    public func applying(to filters: StationFilters) -> StationFilters {
        var result = filters
        result.preference = preference
        result.minimumPowerKW = minimumPowerKW
        result.socketFilters = socketFilters
        result.operatorFilters = operatorFilters
        result.rangeFilterEnabled = rangeFilterEnabled
        return result
    }
}

public struct SearchIntentObservation: Hashable, Sendable {
    public var occurredAt: Date
    public var contextKey: String
    public var parameters: SearchIntentParameters

    public init(occurredAt: Date, contextKey: String, parameters: SearchIntentParameters) {
        self.occurredAt = occurredAt
        self.contextKey = contextKey
        self.parameters = parameters
    }
}

public struct SearchIntentPrediction: Equatable, Sendable {
    public var parameters: SearchIntentParameters
    public var confidence: Double
    public var supportingSamples: Int
    public var distinctDays: Int

    public init(
        parameters: SearchIntentParameters,
        confidence: Double,
        supportingSamples: Int,
        distinctDays: Int
    ) {
        self.parameters = parameters
        self.confidence = confidence
        self.supportingSamples = supportingSamples
        self.distinctDays = distinctDays
    }
}

public enum PredictiveIntentEngine {
    public static func predictSearch(
        observations: [SearchIntentObservation],
        contextKey: String,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent,
        minimumConfidence: Double = 0.90
    ) -> SearchIntentPrediction? {
        let cutoff = now.addingTimeInterval(-60 * 86_400)
        let relevant = observations.filter {
            $0.contextKey == contextKey && $0.occurredAt >= cutoff && $0.occurredAt <= now
        }
        guard relevant.count >= 6 else { return nil }

        let grouped = Dictionary(grouping: relevant, by: \SearchIntentObservation.parameters)
        guard let winner = grouped.max(by: { $0.value.count < $1.value.count }) else { return nil }
        let confidence = Double(winner.value.count) / Double(relevant.count)
        let days = Set(winner.value.map { calendar.startOfDay(for: $0.occurredAt) }).count
        guard confidence >= minimumConfidence, days >= 5 else { return nil }

        return SearchIntentPrediction(
            parameters: winner.key,
            confidence: confidence,
            supportingSamples: winner.value.count,
            distinctDays: days
        )
    }
}
