import Foundation

public struct StationCandidate: Identifiable, Hashable, Sendable {
    public var station: Station
    public var status: StationStatusSummary?
    public var distanceKm: Double
    public var straightLineDistanceKm: Double
    public var estimatedMinutes: Int
    public var arrivalChargePercent: Double
    public var remainingSafeRangeKm: Double
    public var routeDeviationKm: Double
    public var score: Int
    public var badges: [StationBadge]

    public var id: String { station.id }

    public init(
        station: Station,
        status: StationStatusSummary? = nil,
        distanceKm: Double,
        straightLineDistanceKm: Double,
        estimatedMinutes: Int,
        arrivalChargePercent: Double,
        remainingSafeRangeKm: Double,
        routeDeviationKm: Double = 0,
        score: Int,
        badges: [StationBadge]
    ) {
        self.station = station
        self.status = status
        self.distanceKm = distanceKm
        self.straightLineDistanceKm = straightLineDistanceKm
        self.estimatedMinutes = estimatedMinutes
        self.arrivalChargePercent = arrivalChargePercent
        self.remainingSafeRangeKm = remainingSafeRangeKm
        self.routeDeviationKm = routeDeviationKm
        self.score = score
        self.badges = badges
    }

    public var hasRiskyStatus: Bool {
        status?.durum == "riskli"
    }
}

public struct StationBadge: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case risk
        case lastPositive
        case noLiveData
        case arrivalSafe
        case arrivalLow
        case fastDC
        case dc
        case sources(Int)
        case highConfidence
    }

    public enum Tone: String, Sendable {
        case good
        case warning
        case info
        case risk
    }

    public var kind: Kind
    public var tone: Tone

    public init(kind: Kind, tone: Tone) {
        self.kind = kind
        self.tone = tone
    }
}
