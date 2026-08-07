import Foundation
import Testing
@testable import SarjBulCore

@Suite
struct ImplicitFeedbackEngineTests {
    @Test
    func fastRouteActionTeachesMoreThanSlowDetailView() {
        let features = StationPreferenceVector(
            proximity: 0.8,
            chargingSpeed: 1,
            economy: 0.5,
            dataConfidence: 0.9,
            availability: 0.8
        )
        let routeProfile = ImplicitFeedbackEngine.updated(
            profile: ImplicitUserProfile(),
            features: features,
            signal: .routeOpened,
            actionLatency: 3
        )
        let detailProfile = ImplicitFeedbackEngine.updated(
            profile: ImplicitUserProfile(),
            features: features,
            signal: .detailsOpened,
            actionLatency: 90
        )

        #expect(routeProfile.weights.chargingSpeed > detailProfile.weights.chargingSpeed)
        #expect(routeProfile.observationCount == 1)
    }

    @Test
    func ignoreSignalCannotEraseStrongRoutePreference() {
        let features = StationPreferenceVector(proximity: 1, chargingSpeed: 1, economy: 1, dataConfidence: 1, availability: 1)
        let positive = ImplicitFeedbackEngine.updated(
            profile: ImplicitUserProfile(),
            features: features,
            signal: .routeOpened,
            actionLatency: 2
        )
        let ignored = ImplicitFeedbackEngine.updated(
            profile: positive,
            features: features,
            signal: .ignored,
            actionLatency: 10
        )

        #expect(ignored.weights.proximity > 0)
        #expect(ignored.weights.proximity < positive.weights.proximity)
    }

    @Test
    func personalizationNeverMovesAStationAcrossIntentWindows() {
        let candidates = (0..<8).map { index in
            candidate(id: "station-\(index)", power: index == 7 ? 200 : Double(index + 1))
        }
        let profile = ImplicitUserProfile(
            weights: StationPreferenceVector(chargingSpeed: 1),
            observationCount: 8
        )

        let ranked = ImplicitFeedbackEngine.rerank(candidates, profile: profile)

        #expect(Set(ranked.prefix(4).map(\.id)) == Set(candidates.prefix(4).map(\.id)))
        #expect(ranked[4].id == "station-7")
    }

    @Test
    func learnedWeightsRemainBounded() {
        let features = StationPreferenceVector(proximity: 1, chargingSpeed: 1, economy: 1, dataConfidence: 1, availability: 1)
        let profile = (0..<200).reduce(ImplicitUserProfile()) { value, _ in
            ImplicitFeedbackEngine.updated(
                profile: value,
                features: features,
                signal: .routeOpened,
                actionLatency: 0
            )
        }

        #expect(profile.weights.proximity == 1)
        #expect(profile.weights.availability == 1)
    }

    private func candidate(id: String, power: Double) -> StationCandidate {
        StationCandidate(
            station: Station(
                id: id,
                name: id,
                address: "Izmir",
                latitude: 38.4,
                longitude: 27.1,
                power: "\(power) kW",
                operatorName: "Test",
                socket: "CCS2",
                price: "10 TL/kWh",
                source: "test"
            ),
            distanceKm: 5,
            straightLineDistanceKm: 4,
            estimatedMinutes: 8,
            arrivalChargePercent: 30,
            remainingSafeRangeKm: 50,
            score: 70,
            badges: []
        )
    }
}
