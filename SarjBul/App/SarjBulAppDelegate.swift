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
        guard content.categoryIdentifier == AutonomousNotificationConstants.category,
              response.actionIdentifier == AutonomousNotificationConstants.openRouteAction
                || response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let stationKey = content.userInfo[AutonomousNotificationConstants.stationKey] as? String else {
            return
        }
        PendingAutonomousRouteStore.set(stationKey: stationKey)
    }
}
