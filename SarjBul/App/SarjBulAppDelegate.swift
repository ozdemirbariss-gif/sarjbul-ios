import UIKit
@preconcurrency import UserNotifications

final class SarjBulAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let content = response.notification.request.content
        guard content.categoryIdentifier == AutonomousNotificationConstants.category else { return }

        switch response.actionIdentifier {
        case AutonomousNotificationConstants.openRouteAction, UNNotificationDefaultActionIdentifier:
            guard let stationKey = content.userInfo[AutonomousNotificationConstants.stationKey] as? String else {
                return
            }
            PendingAutonomousRouteStore.set(stationKey: stationKey)
        case AutonomousNotificationConstants.snoozeAction:
            let request = UNNotificationRequest(
                identifier: "autonomous-charging-proposal-snoozed",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 15 * 60, repeats: false)
            )
            try? await center.add(request)
        case AutonomousNotificationConstants.muteTodayAction:
            PendingAutonomousRouteStore.muteUntilTomorrow()
            center.removePendingNotificationRequests(withIdentifiers: [
                "autonomous-charging-proposal",
                "autonomous-charging-proposal-snoozed"
            ])
        default:
            break
        }
    }
}
