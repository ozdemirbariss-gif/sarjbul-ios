import Foundation

public struct OccupancyPrediction: Equatable, Sendable {
    public enum Confidence: String, Sendable {
        case low
        case medium
        case high
    }

    public var busyProbability: Double
    public var confidence: Confidence
    public var sampleCount: Int

    public init(busyProbability: Double, confidence: Confidence, sampleCount: Int) {
        self.busyProbability = min(1, max(0, busyProbability))
        self.confidence = confidence
        self.sampleCount = sampleCount
    }
}

public enum OccupancyPredictor {
    public static func predict(
        station: Station,
        insight: StationCommunityInsight?,
        date: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> OccupancyPrediction {
        let weekday = calendar.component(.weekday, from: date)
        let hour = calendar.component(.hour, from: date)
        let bucket = insight?.occupancy["\(weekday)-\(hour)"]
        let prior = contextualPrior(station: station, weekday: weekday, hour: hour)
        let sampleCount = bucket?.total ?? 0
        let observedBusy = bucket?.busy ?? 0

        // A four-observation Bayesian prior prevents tiny samples from looking certain.
        let probability = (Double(observedBusy) + prior * 4) / Double(sampleCount + 4)
        let confidence: OccupancyPrediction.Confidence = if sampleCount >= 12 {
            .high
        } else if sampleCount >= 4 {
            .medium
        } else {
            .low
        }
        return OccupancyPrediction(
            busyProbability: probability,
            confidence: confidence,
            sampleCount: sampleCount
        )
    }

    private static func contextualPrior(station: Station, weekday: Int, hour: Int) -> Double {
        let text = "\(station.name) \(station.address)"
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
        let weekend = weekday == 1 || weekday == 7
        let evening = (17...21).contains(hour)

        if text.contains("avm") || text.contains("mall") {
            return weekend && (12...20).contains(hour) ? 0.72 : evening ? 0.58 : 0.40
        }
        if text.contains("otoyol") || text.contains("dinlenme") || text.contains("tesis") {
            return weekend ? 0.60 : 0.42
        }
        if text.contains("otel") || text.contains("hotel") {
            return (18...23).contains(hour) ? 0.62 : 0.34
        }
        return evening ? 0.56 : 0.32
    }
}
