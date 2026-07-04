import Foundation
import Testing
@testable import SarjBulCore

@Suite
struct StationSearchEngineTests {
    @Test
    func safeRangeMatchesOriginalFormula() {
        let profile = DrivingProfile(
            batteryKWh: 75,
            chargePercent: 30,
            consumptionKWhPer100Km: 16.9,
            safetyMarginPercent: 25
        )

        #expect(Int(profile.safeRangeKm.rounded()) == 100)
    }

    @Test
    func nearestPreferenceSortsByDistance() throws {
        let stations = try loadFixture()
        let engine = StationSearchEngine()
        let candidates = engine.candidates(
            from: stations,
            origin: UserLocation(latitude: 38.3939, longitude: 27.1891, source: .manual),
            profile: DrivingProfile(chargePercent: 80),
            filters: StationFilters(preference: .nearest)
        )

        #expect(candidates.first?.station.id == "near_ac")
    }

    @Test
    func fastestPreferencePromotesHighPowerStation() throws {
        let stations = try loadFixture()
        let engine = StationSearchEngine()
        let candidates = engine.candidates(
            from: stations,
            origin: UserLocation(latitude: 38.3939, longitude: 27.1891, source: .manual),
            profile: DrivingProfile(chargePercent: 80),
            filters: StationFilters(preference: .fastest)
        )

        #expect(candidates.first?.station.id == "fast_dc")
    }

    private func loadFixture() throws -> [Station] {
        let url = try #require(Bundle.module.url(forResource: "stations.fixture", withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Station].self, from: data)
    }
}

