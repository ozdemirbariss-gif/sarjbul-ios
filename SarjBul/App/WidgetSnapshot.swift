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

enum WidgetContextKind: String, Codable {
    case activeCharging
    case criticalRange
}

struct WidgetContextSnapshot: Codable {
    var kind: WidgetContextKind
    var title: String
    var subtitle: String
    var value: String
    var icon: String
    var deepLink: String
    var updatedAt: Date
    var endDate: Date?

    var isRelevant: Bool {
        switch kind {
        case .activeCharging:
            endDate.map { $0 > Date() } ?? false
        case .criticalRange:
            Date().timeIntervalSince(updatedAt) < 12 * 60 * 60
        }
    }
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

enum WidgetContextSnapshotStore {
    private static let key = "contextSnapshot"

    static func save(_ snapshot: WidgetContextSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: WidgetSnapshotStore.suiteName)?.set(data, forKey: key)
        reload()
    }

    static func clear(kind: WidgetContextKind? = nil) {
        if let kind, load()?.kind != kind { return }
        UserDefaults(suiteName: WidgetSnapshotStore.suiteName)?.removeObject(forKey: key)
        reload()
    }

    static func load() -> WidgetContextSnapshot? {
        guard let data = UserDefaults(suiteName: WidgetSnapshotStore.suiteName)?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetContextSnapshot.self, from: data),
              snapshot.isRelevant else { return nil }
        return snapshot
    }

    private static func reload() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "SarjBulNearestWidget")
        #endif
    }
}
