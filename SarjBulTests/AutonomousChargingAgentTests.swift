import Foundation
import Testing
@testable import SarjBulCore

@Suite
struct AutonomousChargingAgentTests {
    @Test
    func locationFreshnessRejectsOldAndFutureSamples() {
        let now = Date()
        let fresh = UserLocation(
            latitude: 38.3939,
            longitude: 27.1891,
            source: .device,
            capturedAt: now.addingTimeInterval(-60)
        )
        let old = UserLocation(
            latitude: 38.3939,
            longitude: 27.1891,
            source: .device,
            capturedAt: now.addingTimeInterval(-901)
        )
        let future = UserLocation(
            latitude: 38.3939,
            longitude: 27.1891,
            source: .device,
            capturedAt: now.addingTimeInterval(60)
        )

        #expect(fresh.isFresh(at: now, maximumAge: 900))
        #expect(!old.isFresh(at: now, maximumAge: 900))
        #expect(!future.isFresh(at: now, maximumAge: 900))
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func lowChargeCreatesExplainableSafeProposal() {
        let decision = AutonomousChargingDecisionEngine().evaluate(
            telemetry: telemetry(chargePercent: 22),
            candidates: [candidate(score: 78, arrivalPercent: 16)],
            policy: AutonomousChargingPolicy(isEnabled: true),
            trigger: .vehicleConnected,
            now: now
        )

        guard case .propose(let proposal) = decision else {
            Issue.record("Expected a prepared charging proposal")
            return
        }
        #expect(proposal.stationKey == "agent_station")
        #expect(proposal.arrivalChargePercent == 16)
        #expect(proposal.trigger == .vehicleConnected)
    }

    @Test
    func sufficientChargeDoesNotInterruptDriver() {
        let decision = AutonomousChargingDecisionEngine().evaluate(
            telemetry: telemetry(chargePercent: 72),
            candidates: [candidate(score: 80, arrivalPercent: 60)],
            policy: AutonomousChargingPolicy(isEnabled: true),
            trigger: .backgroundRefresh,
            now: now
        )

        #expect(decision == .noAction(.chargeSufficient))
    }

    @Test
    func cooldownPreventsRepeatedNotifications() {
        let previous = AutonomousChargingProposal(
            stationKey: "agent_station",
            stationName: "Agent Station",
            distanceKm: 4.2,
            estimatedMinutes: 8,
            arrivalChargePercent: 16,
            stationScore: 78,
            telemetrySource: .manualProfile,
            trigger: .appLaunch,
            generatedAt: now.addingTimeInterval(-60 * 60),
            expiresAt: now.addingTimeInterval(60 * 60)
        )
        let decision = AutonomousChargingDecisionEngine().evaluate(
            telemetry: telemetry(chargePercent: 22),
            candidates: [candidate(score: 78, arrivalPercent: 16)],
            policy: AutonomousChargingPolicy(isEnabled: true),
            trigger: .backgroundRefresh,
            lastProposal: previous,
            now: now
        )

        #expect(decision == .noAction(.cooldownActive))
    }

    private func telemetry(chargePercent: Int) -> VehicleTelemetrySnapshot {
        VehicleTelemetrySnapshot(
            chargePercent: chargePercent,
            batteryKWh: 75,
            consumptionKWhPer100Km: 16.9,
            source: .manualProfile,
            isVehicleConnected: false,
            capturedAt: now
        )
    }

    private func candidate(score: Int, arrivalPercent: Double) -> StationCandidate {
        StationCandidate(
            station: Station(
                id: "agent_station",
                name: "Agent Station",
                address: "Izmir",
                latitude: 38.4,
                longitude: 27.1,
                power: "180 kW",
                operatorName: "Test",
                socket: "CCS2",
                price: "9 TL/kWh",
                source: "test"
            ),
            distanceKm: 4.2,
            straightLineDistanceKm: 3.5,
            estimatedMinutes: 8,
            arrivalChargePercent: arrivalPercent,
            remainingSafeRangeKm: 20,
            score: score,
            badges: []
        )
    }
}
