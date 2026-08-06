import ActivityKit
import Foundation

struct ChargingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var endDate: Date
        var initialPercent: Int
        var targetPercent: Int
    }

    var stationName: String
    var languageCode: String
}
