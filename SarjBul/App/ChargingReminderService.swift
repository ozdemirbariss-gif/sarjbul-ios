import Foundation
import UserNotifications

actor ChargingReminderService {
    static let shared = ChargingReminderService()

    private let center = UNUserNotificationCenter.current()
    private let identifier = "charging-reminder"

    func schedule(afterMinutes minutes: Int, title: String, body: String) async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { throw ChargingReminderError.permissionDenied }

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(max(1, minutes) * 60),
            repeats: false
        )
        try await center.add(UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        ))
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

enum ChargingReminderError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        "Notification permission is disabled."
    }
}
