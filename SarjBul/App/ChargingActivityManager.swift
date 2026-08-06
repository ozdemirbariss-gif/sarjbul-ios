@preconcurrency import ActivityKit
import Foundation

@MainActor
final class ChargingActivityManager {
    static let shared = ChargingActivityManager()

    private var activity: Activity<ChargingActivityAttributes>?

    func start(
        stationName: String,
        minutes: Int,
        initialPercent: Int,
        targetPercent: Int,
        languageCode: String
    ) async {
        await start(
            stationName: stationName,
            startedAt: Date(),
            endDate: Date().addingTimeInterval(TimeInterval(minutes * 60)),
            initialPercent: initialPercent,
            targetPercent: targetPercent,
            languageCode: languageCode
        )
    }

    func start(
        stationName: String,
        startedAt: Date,
        endDate: Date,
        initialPercent: Int,
        targetPercent: Int,
        languageCode: String
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await stop()
        let state = ChargingActivityAttributes.ContentState(
            startedAt: startedAt,
            endDate: endDate,
            initialPercent: initialPercent,
            targetPercent: targetPercent
        )
        do {
            activity = try Activity.request(
                attributes: ChargingActivityAttributes(
                    stationName: stationName,
                    languageCode: languageCode
                ),
                content: ActivityContent(state: state, staleDate: state.endDate),
                pushType: nil
            )
        } catch {
            AppLogger.data.warning("Live Activity could not start: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stop() async {
        let currentActivities = Activity<ChargingActivityAttributes>.activities
        activity = nil
        for currentActivity in currentActivities {
            let finalState = currentActivity.content.state
            await currentActivity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }
}
