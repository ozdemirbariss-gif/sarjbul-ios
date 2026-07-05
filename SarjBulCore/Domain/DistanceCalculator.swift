import Foundation

public enum DistanceCalculator {
    public static let roadStretchMultiplier = 1.25
    public static let averageSpeedKmh = 45.0

    public static func haversineKm(
        from origin: UserLocation,
        toLatitude latitude: Double,
        longitude: Double
    ) -> Double {
        let radius = 6371.0
        let phi1 = origin.latitude * .pi / 180
        let phi2 = latitude * .pi / 180
        let deltaPhi = (latitude - origin.latitude) * .pi / 180
        let deltaLambda = (longitude - origin.longitude) * .pi / 180
        let a = sin(deltaPhi / 2) * sin(deltaPhi / 2)
            + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
        return radius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    public static func estimatedRoadDistanceKm(straightLineKm: Double) -> Double {
        straightLineKm * roadStretchMultiplier
    }

    public static func estimatedMinutes(distanceKm: Double) -> Int {
        guard distanceKm > 0 else { return 0 }
        return max(1, Int((distanceKm / averageSpeedKmh * 60).rounded()))
    }
}
