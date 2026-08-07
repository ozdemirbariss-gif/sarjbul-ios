import Foundation
import Observation
import SarjBulCore
@preconcurrency import UserNotifications

@MainActor
@Observable
final class ContextIntelligenceStore {
    private let persistence: any AppPersistence
    private let habits: HabitStore
    private let settings: UserSettingsStore
    private let calendar: CalendarContextClient
    private let health: HealthContextClient
    private let weather: WeatherContextClient
    private var currentCalendarItem: ContextCalendarItem?

    private(set) var policy: ContextIntelligencePolicy
    private(set) var recommendation: ContextRecommendation?
    private(set) var reports: [ContextActionReport]
    private(set) var isEvaluating = false

    var latestReport: ContextActionReport? { reports.first }
    var recentAutomaticReport: ContextActionReport? {
        guard let report = reports.first,
              report.outcome == .automaticallyCompleted,
              Date().timeIntervalSince(report.createdAt) < 12 * 3_600 else { return nil }
        return report
    }

    init(
        persistence: any AppPersistence,
        habits: HabitStore,
        settings: UserSettingsStore,
        calendar: CalendarContextClient = CalendarContextClient(),
        health: HealthContextClient = HealthContextClient(),
        weather: WeatherContextClient = WeatherContextClient()
    ) {
        self.persistence = persistence
        self.habits = habits
        self.settings = settings
        self.calendar = calendar
        self.health = health
        self.weather = weather
        policy = persistence.contextIntelligencePolicy
        reports = persistence.contextActionReports
    }

    func setEnabled(_ enabled: Bool) async {
        policy.isEnabled = enabled
        persistence.contextIntelligencePolicy = policy
        if enabled {
            _ = await calendar.requestAuthorization()
            if policy.usesHealthSignals { _ = await health.requestAuthorization() }
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } else {
            recommendation = nil
        }
    }

    func setUsesHealthSignals(_ enabled: Bool) async {
        policy.usesHealthSignals = enabled
        persistence.contextIntelligencePolicy = policy
        if enabled { _ = await health.requestAuthorization() }
    }

    func setUsesWeather(_ enabled: Bool) {
        policy.usesWeather = enabled
        persistence.contextIntelligencePolicy = policy
    }

    func setAutomaticCalendarChanges(_ enabled: Bool) async {
        policy.allowsAutomaticCalendarChanges = enabled
        persistence.contextIntelligencePolicy = policy
        if enabled { _ = await calendar.requestAuthorization() }
    }

    func evaluate(
        location: UserLocation?,
        movementSpeedMetersPerSecond: Double? = nil,
        now: Date = Date()
    ) async {
        guard policy.isEnabled, !isEvaluating else { return }
        isEvaluating = true
        defer { isEvaluating = false }

        let item = calendar.nextItem(now: now)
        currentCalendarItem = item
        async let heartTask = policy.usesHealthSignals ? health.latestContext() : HeartContext()
        async let weatherTask = weatherContext(location: location)
        let heart = await heartTask
        let currentWeather = await weatherTask
        let acceptedCount = reports.filter { $0.action == .offerCalendarDeferral && $0.outcome == .accepted }.count
        let snapshot = UserContextSnapshot(
            isEnabled: true,
            isInTransit: (movementSpeedMetersPerSecond ?? 0) >= 4.5,
            currentHeartRate: heart.current,
            restingHeartRate: heart.resting,
            heartRateSampleAge: heart.sampleDate.map { max(0, now.timeIntervalSince($0)) },
            weatherSeverity: currentWeather.severity,
            hasUpcomingCalendarItem: item != nil,
            minutesUntilCalendarItem: item.map { Int($0.startDate.timeIntervalSince(now) / 60) },
            priorAcceptedDeferrals: acceptedCount,
            habitObservationCount: habits.implicitProfile.observationCount,
            hasMatchingRoutine: habits.suggestion(at: now) != nil,
            allowsAutomaticCalendarChanges: policy.allowsAutomaticCalendarChanges
        )
        recommendation = UserContextEngine.recommendation(for: snapshot)
        guard recommendation?.action == .automaticallyDeferCalendar, !hasRecentCalendarAction(now: now) else { return }
        await applyCalendarDeferral(outcome: .automaticallyCompleted, now: now)
    }

    func acceptRecommendation(now: Date = Date()) async {
        guard let recommendation else { return }
        switch recommendation.action {
        case .offerCalendarDeferral, .automaticallyDeferCalendar:
            await applyCalendarDeferral(outcome: .accepted, now: now)
        case .suggestRecoveryPause:
            record(ContextActionReport(action: .suggestRecoveryPause, outcome: .accepted, createdAt: now))
            self.recommendation = nil
        }
    }

    func dismissRecommendation(now: Date = Date()) {
        guard let recommendation else { return }
        record(ContextActionReport(action: recommendation.action, outcome: .skipped, createdAt: now))
        self.recommendation = nil
    }

    func refreshInBackground(location: UserLocation?) async {
        await evaluate(location: location)
    }

    private func weatherContext(location: UserLocation?) async -> ContextWeather {
        guard policy.usesWeather, let location else { return ContextWeather(severity: .normal) }
        return await weather.current(at: location)
    }

    private func applyCalendarDeferral(outcome: ContextActionOutcome, now: Date) async {
        guard let recommendation, let item = currentCalendarItem else { return }
        do {
            try calendar.deferItem(item, by: recommendation.delaySeconds)
            record(ContextActionReport(action: .offerCalendarDeferral, outcome: outcome, createdAt: now))
            self.recommendation = nil
            await notifyCalendarOptimized()
        } catch {
            AppTelemetry.capture(error, operation: "context_calendar_deferral")
        }
    }

    private func hasRecentCalendarAction(now: Date) -> Bool {
        reports.contains {
            ($0.outcome == .accepted || $0.outcome == .automaticallyCompleted)
                && now.timeIntervalSince($0.createdAt) < 4 * 3_600
        }
    }

    private func record(_ report: ContextActionReport) {
        reports.insert(report, at: 0)
        reports = Array(reports.prefix(40))
        persistence.contextActionReports = reports
    }

    private func notifyCalendarOptimized() async {
        let content = UNMutableNotificationContent()
        content.title = settings.t("context.notification_title")
        content.body = settings.t("context.notification_body")
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "context-calendar-optimized",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
