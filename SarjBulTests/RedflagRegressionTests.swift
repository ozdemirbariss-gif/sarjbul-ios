import Foundation
import Testing
@testable import SarjBulCore

@Suite
struct RedflagRegressionTests {
    @Test func roadDistanceReplacesEstimatedReachabilityAndRanking() {
        let profile = DrivingProfile(batteryKWh: 50, chargePercent: 30, consumptionKWhPer100Km: 20)
        let original = candidate("ferry", distance: 20)
        let road = original.applyingRoadRoute(distanceKm: 90, minutes: 110, profile: profile)
        #expect(road.roadDistanceVerified)
        #expect(road.distanceKm > profile.safeRangeKm)
        #expect(road.arrivalChargePercent == 0)
        #expect(road.remainingSafeRangeKm == 0)
        #expect([road, original].sorted(preference: .nearest).first?.distanceKm == 20)
    }

    @Test func detoursIncreaseDistanceEnergyAndTime() throws {
        let profile = DrivingProfile(batteryKWh: 50, chargePercent: 60, consumptionKWhPer100Km: 20, safetyMarginPercent: 20)
        let straight = candidate("stop", distance: 90)
        var detour = straight
        detour.routeDeviationKm = 40
        detour.routeProgressKm = 90
        detour.distanceKm = 110
        let planner = ChargingTripPlanner()
        let base = try #require(planner.plan(routeDistanceKm: 200, candidates: [straight], profile: profile))
        let diverted = try #require(planner.plan(routeDistanceKm: 200, candidates: [detour], profile: profile))
        #expect(base.distanceKm == 200)
        #expect(diverted.distanceKm == 240)
        #expect(diverted.drivingMinutes > base.drivingMinutes)
        #expect(diverted.chargingMinutes > base.chargingMinutes)
    }

    @Test func verifiedLegsControlFeasibilityAndPublishedTotals() throws {
        let profile = DrivingProfile(batteryKWh: 50, chargePercent: 60, consumptionKWhPer100Km: 20, safetyMarginPercent: 20)
        let stop = candidate("stop", distance: 90)
        let keys = [TripLegKey(from: TripLegKey.origin, to: stop.id), TripLegKey(from: stop.id, to: TripLegKey.destination)]
        let planner = ChargingTripPlanner()
        #expect(planner.plan(routeDistanceKm: 200, candidates: [stop], profile: profile, verifiedLegs: [:]) == nil)
        let plan = try #require(planner.plan(routeDistanceKm: 200, candidates: [stop], profile: profile,
            verifiedLegs: [keys[0]: .init(distanceKm: 100, minutes: 100), keys[1]: .init(distanceKm: 140, minutes: 120)]))
        #expect(plan.distanceKm == 240)
        #expect(plan.drivingMinutes == 220)
        #expect(planner.plan(routeDistanceKm: 200, candidates: [stop], profile: profile,
            verifiedLegs: [keys[0]: .init(distanceKm: 200, minutes: 100), keys[1]: .init(distanceKm: 140, minutes: 120)]) == nil)
    }

    @Test func lowPowerNeverGetsAnArtificialChargingFloor() {
        #expect(ChargingCurve.minutes(from: 20, to: 40, batteryKWh: 50, stationPowerKW: 2) >= 300)
        let noPower = candidate("unknown", distance: 90, power: 0)
        #expect(ChargingTripPlanner().plan(routeDistanceKm: 200, candidates: [noPower],
            profile: DrivingProfile(batteryKWh: 50, chargePercent: 50, consumptionKWhPer100Km: 20)) == nil)
    }

    @Test func vehiclePowerLimitsAndLegacyProfilesAreRespected() throws {
        let legacy = Data(#"{"batteryKWh":50,"chargePercent":50,"consumptionKWhPer100Km":20,"safetyMarginPercent":25}"#.utf8)
        let profile = try JSONDecoder().decode(DrivingProfile.self, from: legacy)
        #expect(profile.chargingPowerKW(for: candidate("dc", distance: 10, power: 350)) == 150)
        var ac = candidate("ac", distance: 10, power: 22)
        ac.station.socket = "Type 2"
        ac.station.chargingUnits = [.init(id: "ac", powerKW: 22, sockets: [.init(id: "ac", type: "Type 2")])]
        #expect(profile.chargingPowerKW(for: ac) == 11)
    }

    @Test func statusExpiryAndLegacySnapshotsCannotInfluenceDecisionsForever() throws {
        let old = StationStatusSummary(durum: "riskli", observedAt: Date().addingTimeInterval(-90_000))
        #expect(old.durum == nil)
        let legacy = try JSONDecoder().decode(StationStatusSummary.self, from: Data(#"{"durum":"aktif"}"#.utf8))
        #expect(legacy.durum == nil)
        let future = StationStatusSummary(durum: "aktif", observedAt: Date().addingTimeInterval(600))
        #expect(future.durum == nil)
    }

    @Test func journeyCandidatePoolKeepsRemoteStopsBeyondDenseOriginCluster() {
        let origin = UserLocation(latitude: 38, longitude: 27, source: .manual)
        let destination = JourneyDestination(name: "End", address: "Test", latitude: 38, longitude: 33)
        var stations = (0..<120).map { index -> Station in
            var station = candidate("city-\(index)", distance: 1).station
            station.longitude = 27.05 + Double(index) * 0.001
            return station
        }
        stations += [28.5, 30, 31.5].enumerated().map { index, longitude in
            var station = candidate("remote-\(index)", distance: 100).station
            station.longitude = longitude
            return station
        }
        let profile = DrivingProfile(batteryKWh: 75, chargePercent: 40, consumptionKWhPer100Km: 18)
        let candidates = StationSearchEngine().candidatesAlongJourney(from: stations, origin: origin,
            destination: destination, profile: profile, filters: StationFilters(preference: .nearest, rangeFilterEnabled: false), limit: Int.max)
        #expect(candidates.count == 123)
        #expect(candidates.contains { $0.id == "remote-2" })
        let distance = DistanceCalculator.haversineKm(from: origin, toLatitude: 38, longitude: 33)
        let plan = ChargingTripPlanner().plan(routeDistanceKm: distance, candidates: candidates, profile: profile)
        #expect(plan?.stops.contains { $0.id.hasPrefix("remote-") } == true)
    }

    @Test func journeyLegsHonorTheConfiguredSafetyReserve() {
        let profile = DrivingProfile(batteryKWh: 50, chargePercent: 50, consumptionKWhPer100Km: 20, safetyMarginPercent: 25)
        let stop = candidate("stop", distance: 80)
        let legs: [TripLegKey: TripLegMetrics] = [
            .init(from: TripLegKey.origin, to: stop.id): .init(distanceKm: 100, minutes: 100),
            .init(from: stop.id, to: TripLegKey.destination): .init(distanceKm: 100, minutes: 100)
        ]
        #expect(100 > profile.safeRangeKm)
        #expect(ChargingTripPlanner().plan(routeDistanceKm: 200, candidates: [stop], profile: profile, verifiedLegs: legs) == nil)
    }

    @Test func energyRoundingDoesNotRejectAReachableAlternative() {
        let profile = DrivingProfile(batteryKWh: 50, chargePercent: 50, consumptionKWhPer100Km: 20, safetyMarginPercent: 25)
        let stop = candidate("stop", distance: 90)
        #expect(90 < profile.safeRangeKm)
        let plan = ChargingTripPlanner().plan(routeDistanceKm: 200, candidates: [stop], profile: profile,
            verifiedLegs: [.init(from: TripLegKey.origin, to: stop.id): .init(distanceKm: 90, minutes: 90),
                           .init(from: stop.id, to: TripLegKey.destination): .init(distanceKm: 110, minutes: 110)])
        #expect(plan != nil)
        #expect(plan?.stops.first?.arrivalPercent == 14)
    }

    @Test func zeroBatteryCannotProduceAReachableTrip() {
        #expect(ChargingTripPlanner().plan(routeDistanceKm: 1, candidates: [], profile: DrivingProfile(chargePercent: 0)) == nil)
    }

    private func candidate(_ id: String, distance: Double, power: Double = 150) -> StationCandidate {
        StationCandidate(station: Station(id: id, name: id, address: "Test", latitude: 38, longitude: 27,
            power: "\(power) kW", operatorName: "Test", socket: "CCS", price: "10", source: "test"),
            distanceKm: distance, straightLineDistanceKm: distance, estimatedMinutes: Int(distance),
            arrivalChargePercent: 20, remainingSafeRangeKm: 50, score: 50, badges: [])
    }
}
