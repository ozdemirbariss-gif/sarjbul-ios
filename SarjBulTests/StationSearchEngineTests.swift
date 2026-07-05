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

    @Test
    func riskyStatusIsDemotedBeforePreferenceSorting() throws {
        let stations = try loadFixture()
        let engine = StationSearchEngine()
        let candidates = engine.candidates(
            from: stations,
            origin: UserLocation(latitude: 38.3939, longitude: 27.1891, source: .manual),
            profile: DrivingProfile(chargePercent: 80),
            filters: StationFilters(preference: .nearest),
            stationStatuses: [
                "near_ac": StationStatusSummary(durum: "riskli", etiket: "Sorun var", toplam: 1)
            ]
        )

        #expect(candidates.first?.station.id == "fast_dc")
    }

    @Test
    func turkishPriceFormatsAreParsed() {
        #expect(NumberParser.firstDecimal(in: "1.250,00 TL") == 1250)
        #expect(NumberParser.firstDecimal(in: "12,50 TL/kWh") == 12.5)
        #expect(NumberParser.firstDecimal(in: "8.00 TL/kWh") == 8)
    }

    @Test
    func positiveStatusTextIsNotClassifiedAsRisk() {
        let statusClass = FirebaseRESTClient.statusClass(status: "Sorunsuz çalışıyor", comment: "")

        #expect(statusClass == "bos")
        #expect(FirebaseRESTClient.statusSummaryState(forStatusClass: statusClass) == "aktif")
    }

    private func loadFixture() throws -> [Station] {
        let url = try #require(Bundle.module.url(forResource: "stations.fixture", withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Station].self, from: data)
    }
}
