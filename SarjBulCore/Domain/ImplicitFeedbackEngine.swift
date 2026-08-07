import Foundation

public struct StationPreferenceVector: Codable, Equatable, Sendable {
    public var proximity: Double
    public var chargingSpeed: Double
    public var economy: Double
    public var dataConfidence: Double
    public var availability: Double

    public init(
        proximity: Double = 0,
        chargingSpeed: Double = 0,
        economy: Double = 0,
        dataConfidence: Double = 0,
        availability: Double = 0
    ) {
        self.proximity = proximity
        self.chargingSpeed = chargingSpeed
        self.economy = economy
        self.dataConfidence = dataConfidence
        self.availability = availability
    }

    fileprivate func dot(_ other: StationPreferenceVector) -> Double {
        proximity * other.proximity
            + chargingSpeed * other.chargingSpeed
            + economy * other.economy
            + dataConfidence * other.dataConfidence
            + availability * other.availability
    }

    fileprivate func applying(_ other: StationPreferenceVector, amount: Double) -> Self {
        Self(
            proximity: Self.bound(proximity + other.proximity * amount),
            chargingSpeed: Self.bound(chargingSpeed + other.chargingSpeed * amount),
            economy: Self.bound(economy + other.economy * amount),
            dataConfidence: Self.bound(dataConfidence + other.dataConfidence * amount),
            availability: Self.bound(availability + other.availability * amount)
        )
    }

    private static func bound(_ value: Double) -> Double {
        min(1, max(-1, value))
    }
}

public struct ImplicitUserProfile: Codable, Equatable, Sendable {
    public var weights: StationPreferenceVector
    public var observationCount: Int
    public var updatedAt: Date?

    public init(
        weights: StationPreferenceVector = StationPreferenceVector(),
        observationCount: Int = 0,
        updatedAt: Date? = nil
    ) {
        self.weights = weights
        self.observationCount = observationCount
        self.updatedAt = updatedAt
    }
}

public enum ImplicitFeedbackSignal: String, Codable, Sendable {
    case routeOpened
    case favoriteAdded
    case detailsOpened
    case mapExpanded
    case shared
    case ignored
    case dismissed
}

public enum ImplicitFeedbackEngine {
    public static let minimumExposureSeconds = 2.0
    public static let minimumObservationsForRanking = 3
    public static let rankingWindowSize = 4

    public static func features(for candidate: StationCandidate) -> StationPreferenceVector {
        let availability: Double
        if candidate.hasRiskyStatus {
            availability = 0
        } else if let live = candidate.liveAvailability, live.totalConnectors > 0 {
            availability = Double(live.availableConnectors) / Double(live.totalConnectors)
        } else if candidate.status?.durum == "aktif" {
            availability = 0.82
        } else {
            availability = 0.42
        }

        let economy: Double
        if candidate.station.priceValue >= 9_999 {
            economy = 0.25
        } else {
            economy = max(0, 1 - candidate.station.priceValue / 25)
        }

        return StationPreferenceVector(
            proximity: max(0, 1 - min(candidate.distanceKm, 50) / 50),
            chargingSpeed: min(1, candidate.station.powerKW / 200),
            economy: economy,
            dataConfidence: min(1, max(0, candidate.station.confidenceScore)),
            availability: min(1, max(0, availability))
        )
    }

    public static func updated(
        profile: ImplicitUserProfile,
        features: StationPreferenceVector,
        signal: ImplicitFeedbackSignal,
        actionLatency: TimeInterval,
        at date: Date = Date()
    ) -> ImplicitUserProfile {
        let amount = signalStrength(signal, latency: actionLatency) * learningRate(profile.observationCount)
        return ImplicitUserProfile(
            weights: profile.weights.applying(features, amount: amount),
            observationCount: profile.observationCount + 1,
            updatedAt: date
        )
    }

    public static func personalizedScore(
        for candidate: StationCandidate,
        profile: ImplicitUserProfile
    ) -> Double {
        profile.weights.dot(features(for: candidate))
    }

    public static func rerank(
        _ candidates: [StationCandidate],
        profile: ImplicitUserProfile
    ) -> [StationCandidate] {
        guard profile.observationCount >= minimumObservationsForRanking else { return candidates }
        return stride(from: 0, to: candidates.count, by: rankingWindowSize).flatMap { start in
            let end = min(start + rankingWindowSize, candidates.count)
            return candidates[start..<end]
                .enumerated()
                .sorted { lhs, rhs in
                    let left = personalizedScore(for: lhs.element, profile: profile)
                    let right = personalizedScore(for: rhs.element, profile: profile)
                    return left == right ? lhs.offset < rhs.offset : left > right
                }
                .map(\.element)
        }
    }

    private static func learningRate(_ observationCount: Int) -> Double {
        max(0.04, 0.20 / sqrt(Double(max(1, observationCount + 1))))
    }

    private static func signalStrength(_ signal: ImplicitFeedbackSignal, latency: TimeInterval) -> Double {
        let speedBonus = 0.65 + 0.35 * exp(-max(0, latency) / 30)
        return switch signal {
        case .routeOpened: 1.0 * speedBonus
        case .favoriteAdded: 0.82 * speedBonus
        case .shared: 0.62 * speedBonus
        case .mapExpanded: 0.30 * speedBonus
        case .detailsOpened: 0.22 * speedBonus
        case .ignored: -0.06
        case .dismissed: -0.18
        }
    }
}
