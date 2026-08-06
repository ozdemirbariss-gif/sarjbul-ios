import BackgroundTasks
import UIKit
@preconcurrency import UserNotifications

final class SarjBulAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AutonomousBackgroundScheduler.processingIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let operation = Task { @MainActor in
                guard let handler = AutonomousBackgroundRuntime.processingHandler else {
                    task.setTaskCompleted(success: false)
                    return
                }
                await handler()
                task.setTaskCompleted(success: !Task.isCancelled)
            }
            task.expirationHandler = { operation.cancel() }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        AutonomousBackgroundScheduler.scheduleAll()
        Task { @MainActor in
            guard let handler = AutonomousBackgroundRuntime.silentPushHandler else {
                completionHandler(.noData)
                return
            }
            await handler()
            completionHandler(.newData)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        AppLogger.data.debug("Remote notification registration unavailable: \(error.localizedDescription, privacy: .public)")
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
