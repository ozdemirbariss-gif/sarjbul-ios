import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct WidgetSnapshot: Codable {
    var stationName: String
    var distanceKm: Double
    var power: String
    var safeRangeKm: Int
    var updatedAt: Date
    var languageCode: String? = nil
}

enum WidgetSnapshotStore {
    static let suiteName = "group.com.ozdemirbaris.sarjbul"
    private static let key = "nearestFastStationSnapshot"

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: key)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "SarjBulNearestWidget")
        #endif
    }

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
