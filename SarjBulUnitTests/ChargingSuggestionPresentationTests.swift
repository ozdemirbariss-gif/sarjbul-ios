import Foundation
import SarjBulCore
import XCTest
@testable import SarjBul

final class ChargingSuggestionPresentationTests: XCTestCase {
    func testUppercaseTurkishStationNamesAreReadableInBothLanguages() {
        XCTAssertEqual(makePresentation().stationName, "Shell Güzelyalı")
        XCTAssertEqual(makePresentation(language: .en).stationName, "Shell Güzelyalı")
        XCTAssertEqual(ChargingSuggestionPresentation.stationName("İZMİR AVM - DC"), "İzmir AVM - DC")
        XCTAssertEqual(ChargingSuggestionPresentation.stationName("BMW OSB (AC/DC)"), "BMW OSB (AC/DC)")
        XCTAssertEqual(ChargingSuggestionPresentation.stationName("  SHELL  GÜZELYALI  "), "  Shell  Güzelyalı  ")
        XCTAssertEqual(ChargingSuggestionPresentation.stationName("otoWATT / ZES"), "otoWATT / ZES")
        XCTAssertEqual(ChargingSuggestionPresentation.stationName(""), "")
    }

    func testManualValuesAreEstimatesNotVehicleMeasurements() {
        var presentation = makePresentation()
        presentation.telemetry = telemetry(source: .manualProfile)
        XCTAssertEqual(presentation.heading, "Şarj önerisi")
        XCTAssertEqual(presentation.source, "Girdiğin sürüş değerlerine göre hesaplandı.")
        XCTAssertEqual(presentation.duration, "Yaklaşık 1 dk")
        XCTAssertEqual(presentation.arrival, "Varış şarjı tahmini: %17")
        XCTAssertEqual(presentation.distance, "Tahmini mesafe: 0,3 km")
        XCTAssertNil(presentation.confirmedLowCharge)
    }

    func testEnglishCopyAndDecimalFormatting() {
        let presentation = makePresentation(language: .en)
        XCTAssertEqual(presentation.heading, "Charging suggestion")
        XCTAssertEqual(presentation.source, "Calculated from the driving values you entered.")
        XCTAssertEqual(presentation.duration, "About 1 min")
        XCTAssertEqual(presentation.arrival, "Estimated arrival charge: 17%")
        XCTAssertEqual(presentation.distance, "Estimated distance: 0.3 km")
        XCTAssertEqual(presentation.text("agent.open_route"), "View route")
    }

    func testOnlyFreshConnectedVehicleDataCanShowLowChargeWarning() {
        var presentation = makePresentation(source: .manufacturerAPI)
        presentation.telemetry = telemetry()
        XCTAssertEqual(presentation.confirmedLowCharge, "Araç şarjı: %20")
        presentation.telemetry?.capturedAt = now.addingTimeInterval(-901)
        XCTAssertNil(presentation.confirmedLowCharge)
        presentation.telemetry?.capturedAt = now.addingTimeInterval(1)
        XCTAssertNil(presentation.confirmedLowCharge)
        presentation.telemetry?.capturedAt = now
        presentation.telemetry?.isVehicleConnected = false
        XCTAssertNil(presentation.confirmedLowCharge)
        presentation.telemetry = telemetry(source: .externalAccessory)
        XCTAssertNil(presentation.confirmedLowCharge)
        presentation.telemetry = nil
        XCTAssertNil(presentation.confirmedLowCharge)
    }

    func testNormalOrInvalidChargeDoesNotShowWarning() {
        var presentation = makePresentation(source: .manufacturerAPI)
        presentation.telemetry = telemetry()
        for charge in [-1, 31, 101] {
            presentation.telemetry?.chargePercent = charge
            XCTAssertNil(presentation.confirmedLowCharge)
        }
        presentation.telemetry?.chargePercent = 20
        presentation.lowChargeThreshold = -1
        XCTAssertNil(presentation.confirmedLowCharge)
    }

    func testReportsAreExplanationsNotSafetyOrExecutionPromises() {
        let rules: [AutomationRuleID] = [.lowCharge, .preparedRouteExpired, .preparedRouteRisky, .stationDataStale]
        for language in AppLanguage.allCases {
            for rule in rules {
                var presentation = makePresentation(language: language)
                presentation.report = AutomationReport(
                    rule: rule, actions: [], selectedStationName: presentation.proposal.stationName
                )
                XCTAssertFalse(presentation.reason.contains("agent."))
                XCTAssertFalse(presentation.reason.contains("{"))
                for phrase in ["tespit ettim", "güvenli", "hazırladım", "I detected", "safe route", "completed"] {
                    XCTAssertFalse(presentation.reason.contains(phrase))
                }
            }
        }
    }

    func testUnrelatedReportIsNotShownAsTheReason() {
        var presentation = makePresentation()
        let fallback = presentation.reason
        presentation.report = AutomationReport(rule: .preparedRouteRisky, actions: [], selectedStationName: "Other")
        XCTAssertEqual(presentation.reason, fallback)
    }

    func testNotificationUsesSameHonestCopy() {
        for language in AppLanguage.allCases {
            let presentation = makePresentation(language: language)
            let body = presentation.text("agent.notification_body", [
                "station": presentation.stationName, "minutes": "1", "percent": "17"
            ])
            XCTAssertTrue(body.contains("Shell Güzelyalı"))
            XCTAssertTrue(body.contains(language == .tr ? "tahmini" : "Estimated"))
            XCTAssertFalse(body.contains("{"))
        }
    }

    private var now: Date { Date(timeIntervalSince1970: 1_800_000_000) }

    private func telemetry(source: VehicleTelemetrySource = .manufacturerAPI) -> VehicleTelemetrySnapshot {
        VehicleTelemetrySnapshot(
            chargePercent: 20, batteryKWh: 75, consumptionKWhPer100Km: 16.9,
            source: source, isVehicleConnected: source != .manualProfile, capturedAt: now
        )
    }

    private func makePresentation(
        language: AppLanguage = .tr, source: VehicleTelemetrySource = .manualProfile
    ) -> ChargingSuggestionPresentation {
        ChargingSuggestionPresentation(
            proposal: AutonomousChargingProposal(
                stationKey: "test", stationName: "SHELL GÜZELYALI", distanceKm: 0.3,
                estimatedMinutes: 1, arrivalChargePercent: 17, stationScore: 80,
                telemetrySource: source, trigger: .appLaunch, generatedAt: now,
                expiresAt: now.addingTimeInterval(3_600)
            ), language: language, now: now
        )
    }
}
