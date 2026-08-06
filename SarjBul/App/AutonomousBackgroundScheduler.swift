import BackgroundTasks
import Foundation

enum AutonomousBackgroundScheduler {
    static let refreshIdentifier = "com.ozdemirbaris.sarjbul.autonomous-refresh"
    static let processingIdentifier = "com.ozdemirbaris.sarjbul.autonomous-processing"
    static let identifier = refreshIdentifier

    static func schedule() {
        scheduleAll()
    }

    static func scheduleAll() {
        scheduleRefresh()
        scheduleProcessing()
    }

    private static func scheduleRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: refreshIdentifier)
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            AppLogger.data.debug("Autonomous refresh was not scheduled: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func scheduleProcessing() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: processingIdentifier)
        let request = BGProcessingTaskRequest(identifier: processingIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 3_600)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            AppLogger.data.debug("Autonomous processing was not scheduled: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func cancel() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: refreshIdentifier)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: processingIdentifier)
    }
}
