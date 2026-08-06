import Foundation
import Testing
@testable import SarjBulCore

@Suite("PredictiveIntentEngineTests")
struct PredictiveIntentEngineTests {
    @Test("consistent behavior across days produces a high confidence prefill")
    func consistentBehaviorProducesPrefill() throws {
        let context = "weekday:morning"
        let now = try #require(Self.calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 6,
            hour: 9
        )))
        let parameters = SearchIntentParameters(
            preference: .fastest,
            minimumPowerKW: 100,
            socketFilters: ["CCS"],
            operatorFilters: [],
            rangeFilterEnabled: true
        )
        let observations = try (1...6).map { day in
            SearchIntentObservation(
                occurredAt: try #require(Self.calendar.date(byAdding: .day, value: -day, to: now)),
                contextKey: context,
                parameters: parameters
            )
        }

        let prediction = PredictiveIntentEngine.predictSearch(
            observations: observations,
            contextKey: context,
            now: now,
            calendar: Self.calendar
        )

        #expect(prediction?.parameters == parameters)
        #expect(prediction?.confidence == 1)
        #expect(prediction?.distinctDays == 6)
    }

    @Test("mixed behavior below ninety percent never changes parameters")
    func uncertainBehaviorDoesNotPrefill() throws {
        let context = "weekday:evening"
        let now = try #require(Self.calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 6,
            hour: 19
        )))
        let fast = SearchIntentParameters(filters: StationFilters(preference: .fastest))
        let near = SearchIntentParameters(filters: StationFilters(preference: .nearest))
        let observations = try (1...10).map { day in
            SearchIntentObservation(
                occurredAt: try #require(Self.calendar.date(byAdding: .day, value: -day, to: now)),
                contextKey: context,
                parameters: day <= 8 ? fast : near
            )
        }

        #expect(PredictiveIntentEngine.predictSearch(
            observations: observations,
            contextKey: context,
            now: now,
            calendar: Self.calendar
        ) == nil)
    }

    @Test("prediction never crosses time context boundaries")
    func contextIsolation() throws {
        let now = try #require(Self.calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 6,
            hour: 19
        )))
        let parameters = SearchIntentParameters(filters: StationFilters(preference: .economical))
        let observations = try (1...8).map { day in
            SearchIntentObservation(
                occurredAt: try #require(Self.calendar.date(byAdding: .day, value: -day, to: now)),
                contextKey: "weekend:morning",
                parameters: parameters
            )
        }

        #expect(PredictiveIntentEngine.predictSearch(
            observations: observations,
            contextKey: "weekday:evening",
            now: now,
            calendar: Self.calendar
        ) == nil)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .gmt
        return calendar
    }
}
