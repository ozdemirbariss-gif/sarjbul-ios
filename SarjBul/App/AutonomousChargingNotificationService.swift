import Foundation
import SarjBulCore
@preconcurrency import UserNotifications

enum AutonomousNotificationConstants {
    static let category = "AUTONOMOUS_CHARGING_PROPOSAL"
    static let openRouteAction = "OPEN_AUTONOMOUS_ROUTE"
    static let stationKey = "stationKey"
}

actor AutonomousChargingNotificationService {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func schedule(proposal: AutonomousChargingProposal, title: String, body: String, actionTitle: String) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }

        let action = UNNotificationAction(
            identifier: AutonomousNotificationConstants.openRouteAction,
            title: actionTitle,
            options: [.foreground]
        )
        center.setNotificationCategories([UNNotificationCategory(
            identifier: AutonomousNotificationConstants.category,
            actions: [action],
            intentIdentifiers: []
        )])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = AutonomousNotificationConstants.category
        content.userInfo = [AutonomousNotificationConstants.stationKey: proposal.stationKey]

        center.removePendingNotificationRequests(withIdentifiers: ["autonomous-charging-proposal"])
        try? await center.add(UNNotificationRequest(
            identifier: "autonomous-charging-proposal",
            content: content,
            trigger: nil
        ))
    }
}

enum PendingAutonomousRouteStore {
    static let didChange = Notification.Name("PendingAutonomousRouteDidChange")
    private static let key = "pendingAutonomousStationKey"

    static func set(stationKey: String) {
        UserDefaults.standard.set(stationKey, forKey: key)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static func consume() -> String? {
        guard let stationKey = UserDefaults.standard.string(forKey: key) else { return nil }
        UserDefaults.standard.removeObject(forKey: key)
        return stationKey
    }
}
