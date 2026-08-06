import Foundation
import SarjBulCore
import XCTest
@testable import SarjBul

@MainActor
final class HabitStoreTests: XCTestCase {
    func testRepeatedStationAcrossThreeDaysCreatesDismissibleSuggestion() throws {
        let context = try makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let station = testStation

        for day in 1...3 {
            let date = try XCTUnwrap(context.calendar.date(byAdding: .day, value: -day, to: context.now))
            context.store.recordRouteOpened(station, at: date)
        }

        let suggestion = try XCTUnwrap(context.store.suggestion(at: context.now, calendar: context.calendar))
        guard case .repeatedStation(let key, let name, .evening) = suggestion else {
            return XCTFail("Expected a repeated station suggestion")
        }
        XCTAssertEqual(key, station.statusKey)
        XCTAssertEqual(name, station.name)

        context.store.dismiss(suggestion, at: context.now)
        XCTAssertNil(context.store.suggestion(at: context.now, calendar: context.calendar))
    }

    func testConsistentPreferenceAcrossThreeDaysCreatesSuggestion() throws {
        let context = try makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        for day in 1...4 {
            let date = try XCTUnwrap(context.calendar.date(byAdding: .day, value: -day, to: context.now))
            context.store.recordSearch(preference: .fastest, at: date)
        }

        let suggestion = try XCTUnwrap(context.store.suggestion(at: context.now, calendar: context.calendar))
        XCTAssertEqual(suggestion, .routePreference(preference: .fastest, period: .evening))
    }

    private func makeContext() throws -> HabitTestContext {
        let suiteName = "HabitStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let persistence = SystemAppPersistence(
            defaults: defaults,
            secureStorage: HabitTestSecureStorage()
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Istanbul"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 6,
            hour: 19
        )))
        return HabitTestContext(
            suiteName: suiteName,
            defaults: defaults,
            store: HabitStore(persistence: persistence),
            calendar: calendar,
            now: now
        )
    }

    private var testStation: Station {
        Station(
            id: "habit-station",
            name: "Alsancak Hızlı Şarj",
            address: "Konak, İzmir",
            latitude: 38.4382,
            longitude: 27.1434,
            power: "180 kW",
            operatorName: "ŞarjBul",
            socket: "CCS2",
            price: "8,90 TL/kWh",
            source: "test"
        )
    }
}

private struct HabitTestContext {
    let suiteName: String
    let defaults: UserDefaults
    let store: HabitStore
    let calendar: Calendar
    let now: Date
}

private final class HabitTestSecureStorage: SecureStorage {
    private var values: [String: Data] = [:]

    func data(for key: String) -> Data? { values[key] }
    func set(_ data: Data, for key: String) { values[key] = data }
    func remove(_ key: String) { values.removeValue(forKey: key) }
}
