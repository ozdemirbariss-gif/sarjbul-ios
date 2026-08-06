import BackgroundTasks
import Foundation

enum AutonomousBackgroundScheduler {
    static let identifier = "com.ozdemirbaris.sarjbul.autonomous-refresh"

    static func schedule() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            AppLogger.data.debug("Autonomous refresh was not scheduled: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func cancel() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
    }
}
