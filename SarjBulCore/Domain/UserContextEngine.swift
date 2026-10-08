import Foundation

public struct ContextIntelligencePolicy: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var usesWeather: Bool
    public var allowsAutomaticCalendarChanges: Bool

    public init(
        isEnabled: Bool = false,
        usesWeather: Bool = true,
        allowsAutomaticCalendarChanges: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.usesWeather = usesWeather
        self.allowsAutomaticCalendarChanges = allowsAutomaticCalendarChanges
    }
}

public enum ContextWeatherSeverity: String, Codable, Sendable {
    case normal
    case rain
    case severe
}

public struct UserContextSnapshot: Equatable, Sendable {
    public var isEnabled: Bool
    public var isInTransit: Bool
    public var weatherSeverity: ContextWeatherSeverity
    public var hasUpcomingCalendarItem: Bool
    public var minutesUntilCalendarItem: Int?
    public var priorAcceptedDeferrals: Int
    public var habitObservationCount: Int
    public var hasMatchingRoutine: Bool
    public var allowsAutomaticCalendarChanges: Bool

    public init(
        isEnabled: Bool,
        isInTransit: Bool,
        weatherSeverity: ContextWeatherSeverity,
        hasUpcomingCalendarItem: Bool,
        minutesUntilCalendarItem: Int?,
        priorAcceptedDeferrals: Int,
        habitObservationCount: Int,
        hasMatchingRoutine: Bool,
        allowsAutomaticCalendarChanges: Bool
    ) {
        self.isEnabled = isEnabled
        self.isInTransit = isInTransit
        self.weatherSeverity = weatherSeverity
        self.hasUpcomingCalendarItem = hasUpcomingCalendarItem
        self.minutesUntilCalendarItem = minutesUntilCalendarItem
        self.priorAcceptedDeferrals = priorAcceptedDeferrals
        self.habitObservationCount = habitObservationCount
        self.hasMatchingRoutine = hasMatchingRoutine
        self.allowsAutomaticCalendarChanges = allowsAutomaticCalendarChanges
    }
}

public enum ContextRecommendationAction: String, Codable, Sendable {
    case offerCalendarDeferral
    case automaticallyDeferCalendar
}

public struct ContextRecommendation: Equatable, Sendable {
    public var action: ContextRecommendationAction
    public var confidence: Double
    public var isInTransit: Bool
    public var adverseWeather: Bool
    public var delaySeconds: TimeInterval

    public init(
        action: ContextRecommendationAction,
        confidence: Double,
        isInTransit: Bool,
        adverseWeather: Bool,
        delaySeconds: TimeInterval = 3_600
    ) {
        self.action = action
        self.confidence = confidence
        self.isInTransit = isInTransit
        self.adverseWeather = adverseWeather
        self.delaySeconds = delaySeconds
    }
}

public enum ContextActionOutcome: String, Codable, Sendable {
    case suggested
    case accepted
    case automaticallyCompleted
    case skipped
}

public struct ContextActionReport: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var action: ContextRecommendationAction
    public var outcome: ContextActionOutcome
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        action: ContextRecommendationAction,
        outcome: ContextActionOutcome,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.action = action
        self.outcome = outcome
        self.createdAt = createdAt
    }
}

public enum UserContextEngine {
    public static let automaticDeferralLearningThreshold = 2

    public static func recommendation(for snapshot: UserContextSnapshot) -> ContextRecommendation? {
        guard snapshot.isEnabled else { return nil }
        let adverseWeather = snapshot.weatherSeverity != .normal
        let imminentItem = snapshot.hasUpcomingCalendarItem
            && (snapshot.minutesUntilCalendarItem.map { (0...90).contains($0) } ?? false)

        if imminentItem, snapshot.isInTransit, adverseWeather {
            let learned = snapshot.priorAcceptedDeferrals >= automaticDeferralLearningThreshold
            let action: ContextRecommendationAction = snapshot.allowsAutomaticCalendarChanges && learned
                ? .automaticallyDeferCalendar
                : .offerCalendarDeferral
            let confidence = min(
                0.96,
                0.68
                    + (adverseWeather ? 0.08 : 0)
                    + (snapshot.hasMatchingRoutine ? 0.06 : 0)
                    + min(0.08, Double(snapshot.habitObservationCount) / 250)
            )
            return ContextRecommendation(
                action: action,
                confidence: confidence,
                isInTransit: true,
                adverseWeather: adverseWeather
            )
        }

        return nil
    }
}
