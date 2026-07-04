import Foundation

public struct UserLocation: Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var source: Source

    public enum Source: String, Sendable {
        case device
        case manual
    }

    public init(latitude: Double, longitude: Double, source: Source) {
        self.latitude = latitude
        self.longitude = longitude
        self.source = source
    }
}

