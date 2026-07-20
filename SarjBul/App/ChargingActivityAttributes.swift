import ActivityKit
import Foundation

struct ChargingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
        var targetPercent: Int
    }

    var stationName: String
}
