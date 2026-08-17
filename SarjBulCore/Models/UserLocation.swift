import Foundation

public struct UserLocation: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var source: Source
    public var capturedAt: Date

    public enum Source: String, Codable, Sendable {
        case device
        case manual
    }

    public init(latitude: Double, longitude: Double, source: Source, capturedAt: Date = Date()) {
        self.latitude = latitude
        self.longitude = longitude
        self.source = source
        self.capturedAt = capturedAt
    }

    public func isFresh(
        at date: Date = Date(),
        maximumAge: TimeInterval,
        allowedFutureSkew: TimeInterval = 5
    ) -> Bool {
        let age = date.timeIntervalSince(capturedAt)
        return age >= -max(0, allowedFutureSkew) && age <= max(0, maximumAge)
    }

    private enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case source
        case capturedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        source = try container.decode(Source.self, forKey: .source)
        capturedAt = try container.decodeIfPresent(Date.self, forKey: .capturedAt) ?? .distantPast
    }
}
