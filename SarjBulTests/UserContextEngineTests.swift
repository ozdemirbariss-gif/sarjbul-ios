import Foundation
import Testing
@testable import SarjBulCore

@Suite
struct UserContextEngineTests {
    @Test
    func elevatedLoadWhileTravellingOffersCalendarDeferral() throws {
        let result = try #require(UserContextEngine.recommendation(for: snapshot()))

        #expect(result.action == .offerCalendarDeferral)
        #expect(result.elevatedPhysiologicalLoad)
    }

    @Test
    func repeatedAcceptanceAndExplicitPolicyEnableAutomaticDeferral() throws {
        var value = snapshot()
        value.priorAcceptedDeferrals = 2
        value.allowsAutomaticCalendarChanges = true

        let result = try #require(UserContextEngine.recommendation(for: value))

        #expect(result.action == .automaticallyDeferCalendar)
    }

    @Test
    func staleHeartRateDoesNotClaimElevatedLoad() throws {
        var value = snapshot()
        value.heartRateSampleAge = 30 * 60
        value.weatherSeverity = .rain

        let result = try #require(UserContextEngine.recommendation(for: value))

        #expect(!result.elevatedPhysiologicalLoad)
        #expect(result.adverseWeather)
    }

    @Test
    func noPermissionMeansNoRecommendation() {
        var value = snapshot()
        value.isEnabled = false

        #expect(UserContextEngine.recommendation(for: value) == nil)
    }

    @Test
    func matchingRoutineRaisesConfidence() throws {
        let baseline = try #require(UserContextEngine.recommendation(for: snapshot()))
        var learned = snapshot()
        learned.hasMatchingRoutine = true

        let personalized = try #require(UserContextEngine.recommendation(for: learned))

        #expect(personalized.confidence > baseline.confidence)
    }

    private func snapshot() -> UserContextSnapshot {
        UserContextSnapshot(
            isEnabled: true,
            isInTransit: true,
            currentHeartRate: 104,
            restingHeartRate: 68,
            heartRateSampleAge: 60,
            weatherSeverity: .normal,
            hasUpcomingCalendarItem: true,
            minutesUntilCalendarItem: 45,
            priorAcceptedDeferrals: 0,
            habitObservationCount: 20,
            hasMatchingRoutine: false,
            allowsAutomaticCalendarChanges: false
        )
    }
}
