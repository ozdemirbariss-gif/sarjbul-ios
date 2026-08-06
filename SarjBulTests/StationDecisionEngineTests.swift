import Foundation
import Testing
@testable import SarjBulCore

@Suite
struct StationDecisionEngineTests {
    @Test
    func freshLiveAvailabilityWinsAndChargingTimeUsesCurve() {
        var candidate = candidate(power: "150 kW", arrival: 20)
        candidate.liveAvailability = LiveStationAvailability(
            stationKey: candidate.station.statusKey,
            availableConnectors: 3,
            totalConnectors: 4,
            updatedAt: Date()
        )

        let summary = StationDecisionEngine.summarize(
            candidate: candidate,
            profile: DrivingProfile(batteryKWh: 75, chargePercent: 40, consumptionKWhPer100Km: 16.9)
        )

        #expect(summary.availability == .live(available: 3, total: 4))
        #expect(summary.arrivalChargePercent == 20)
        #expect(summary.chargeToTargetMinutes == 22)
    }

    @Test
    func riskyStatusOverridesOptimisticAvailability() {
        var candidate = candidate(power: "150 kW", arrival: 20)
        candidate.status = StationStatusSummary(durum: "riskli")
        candidate.liveAvailability = LiveStationAvailability(
            stationKey: candidate.station.statusKey,
            availableConnectors: 3,
            totalConnectors: 4,
            updatedAt: Date()
        )

        let summary = StationDecisionEngine.summarize(candidate: candidate, profile: DrivingProfile())
        #expect(summary.availability == .risky)
    }

    @Test
    func lowConfidenceOccupancyDoesNotPretendToBeLiveData() {
        let summary = StationDecisionEngine.summarize(
            candidate: candidate(power: "22 kW", arrival: 40),
            profile: DrivingProfile()
        )
        #expect(summary.availability == .unknown)
    }

    private func candidate(power: String, arrival: Double) -> StationCandidate {
        StationCandidate(
            station: Station(
                id: "decision_station",
                name: "Decision Station",
                address: "Izmir",
                latitude: 38.4,
                longitude: 27.1,
                power: power,
                operatorName: "Test",
                socket: "CCS2",
                price: "9 TL/kWh",
                source: "test"
            ),
            distanceKm: 5,
            straightLineDistanceKm: 4,
            estimatedMinutes: 8,
            arrivalChargePercent: arrival,
            remainingSafeRangeKm: 20,
            score: 70,
            badges: []
        )
    }
}
