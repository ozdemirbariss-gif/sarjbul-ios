import Foundation

public struct SearchDemandEvent: Codable, Equatable, Sendable {
    public var coarseCell: String
    public var preference: String
    public var radiusBucketKm: Int
    public var resultBucket: String
    public var createdAtMilliseconds: Int64
    public var source: String

    public init(
        location: UserLocation,
        preference: RoutePreference,
        searchRadiusKm: Double,
        resultCount: Int,
        date: Date = Date()
    ) {
        coarseCell = Self.coarseCell(latitude: location.latitude, longitude: location.longitude)
        self.preference = preference.rawValue
        radiusBucketKm = Self.radiusBucket(searchRadiusKm)
        resultBucket = Self.resultBucket(resultCount)
        createdAtMilliseconds = Int64(date.timeIntervalSince1970 * 1_000)
        source = "ios_opt_in"
    }

    public static func coarseCell(latitude: Double, longitude: Double) -> String {
        let latitudeBucket = floor(latitude * 10) / 10
        let longitudeBucket = floor(longitude * 10) / 10
        return String(
            format: "%.1f_%.1f",
            locale: Locale(identifier: "en_US_POSIX"),
            latitudeBucket,
            longitudeBucket
        ).replacingOccurrences(of: ".", with: "p")
    }

    private static func radiusBucket(_ radius: Double) -> Int {
        [25, 50, 100, 200, 400].first(where: { radius <= Double($0) }) ?? 800
    }

    private static func resultBucket(_ count: Int) -> String {
        switch count {
        case 0: "0"
        case 1...5: "1-5"
        case 6...20: "6-20"
        default: "21+"
        }
    }
}
