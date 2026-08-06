import Foundation
import Testing
@testable import SarjBulCore

@Suite
struct TriggerActionEngineTests {
    @Test
    func riskyPreparedRouteIsRefreshedAndReplacedFirst() {
        let plan = TriggerActionEngine().plan(for: snapshot(
            hasPreparedRoute: true,
            preparedRouteIsRisky: true
        ))

        #expect(plan?.rule == .preparedRouteRisky)
        #expect(plan?.actions == [.refreshStationData, .replacePreparedRoute])
    }

    @Test
    func staleDataIsRefreshedBeforeLowChargeRouteIsPrepared() {
        let plan = TriggerActionEngine().plan(for: snapshot(
            stationDataAge: 7 * 3_600
        ))

        #expect(plan?.rule == .stationDataStale)
        #expect(plan?.actions == [.refreshStationData, .prepareChargingRoute])
    }

    @Test
    func healthyPreparedRouteNeedsNoWork() {
        let plan = TriggerActionEngine().plan(for: snapshot(hasPreparedRoute: true))
        #expect(plan == nil)
    }

    private func snapshot(
        stationDataAge: TimeInterval? = 60,
        hasPreparedRoute: Bool = false,
        preparedRouteIsRisky: Bool = false
    ) -> AutomationSnapshot {
        AutomationSnapshot(
            isEnabled: true,
            chargePercent: 20,
            triggerChargePercent: 30,
            stationDataAge: stationDataAge,
            hasPreparedRoute: hasPreparedRoute,
            preparedRouteIsRisky: preparedRouteIsRisky,
            preparedRouteIsExpired: false
        )
    }
}
