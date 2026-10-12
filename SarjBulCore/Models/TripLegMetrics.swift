import Foundation

public struct TripLegKey: Hashable, Sendable {
    public static let origin = "__origin__"
    public static let destination = "__destination__"
    public var from: String
    public var to: String

    public init(from: String, to: String) { self.from = from; self.to = to }
}

public struct TripLegMetrics: Equatable, Sendable {
    public var distanceKm: Double
    public var minutes: Double

    public init(distanceKm: Double, minutes: Double) {
        self.distanceKm = distanceKm
        self.minutes = minutes
    }
}

public extension StationCandidate {
    var planningProgressKm: Double {
        routeProgressKm ?? max(0, distanceKm - routeDeviationKm / 2)
    }

    func applyingRoadRoute(distanceKm: Double, minutes: Int, profile: DrivingProfile) -> Self {
        var result = self
        result.distanceKm = distanceKm
        result.estimatedMinutes = minutes
        result.arrivalChargePercent = profile.arrivalChargePercent(distanceKm: distanceKm)
        result.remainingSafeRangeKm = max(0, profile.safeRangeKm - distanceKm)
        result.roadDistanceVerified = true
        result.score = StationScorer.score(candidate: result)
        result.badges = StationScorer.badges(for: result)
        return result
    }
}
