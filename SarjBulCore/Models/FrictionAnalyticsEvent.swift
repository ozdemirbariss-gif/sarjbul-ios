import Foundation

public struct FrictionAnalyticsEvent: Codable, Equatable, Sendable {
    public var kind: String
    public var elapsedBucket: String
    public var journeyPhase: String
    public var createdAtMilliseconds: Int64
    public var source: String

    public init(
        kind: String,
        elapsedMilliseconds: Int,
        journeyPhase: String,
        date: Date = Date()
    ) {
        self.kind = kind
        elapsedBucket = switch elapsedMilliseconds {
        case ..<1_000: "under_1s"
        case ..<3_000: "1_3s"
        case ..<10_000: "3_10s"
        case ..<30_000: "10_30s"
        default: "30s_plus"
        }
        self.journeyPhase = journeyPhase
        createdAtMilliseconds = Int64(date.timeIntervalSince1970 * 1_000)
        source = "ios_opt_in"
    }
}
