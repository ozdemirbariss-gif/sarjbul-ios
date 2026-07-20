import AppIntents
import Foundation

struct FindNearestFastChargerIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Nearest Fast Charger"
    static let description = IntentDescription("Opens SarjBul with fast charging prioritized.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        PendingAppIntentStore.set(.nearestFast)
        return .result(dialog: "SarjBul is ready to find the nearest fast charger.")
    }
}

struct SarjBulAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FindNearestFastChargerIntent(),
            phrases: [
                "Find the nearest fast charger with \(.applicationName)",
                "\(.applicationName) ile en yakın hızlı şarjı bul"
            ],
            shortTitle: "Fast Charger",
            systemImageName: "bolt.car.fill"
        )
    }
}

enum PendingAppIntentStore {
    enum Action: String {
        case nearestFast
    }

    private static let key = "pendingAppIntent"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: WidgetSnapshotStore.suiteName) ?? .standard
    }

    static func set(_ action: Action) {
        defaults.set(action.rawValue, forKey: key)
    }

    static func consume() -> Action? {
        guard let raw = defaults.string(forKey: key), let action = Action(rawValue: raw) else {
            return nil
        }
        defaults.removeObject(forKey: key)
        return action
    }
}
