import XCTest

@MainActor
final class AppSmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppOpensDirectlyOnHomeWithoutAuthForm() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-home"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["home-screen"].waitForExistence(timeout: 12))
        XCTAssertFalse(app.buttons["auth-submit-button"].exists)
        XCTAssertFalse(app.buttons["guest-start-button"].exists)
        XCTAssertTrue(app.staticTexts["Konum seç"].exists)
        XCTAssertFalse(app.staticTexts["Hedef ekle"].exists)
    }

    func testStandardLaunchAlwaysStartsOnHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-default-launch"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["home-screen"].waitForExistence(timeout: 12))
    }

    func testHomeShowsOutcomeBeforeAdvancedControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-home"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["prepared-route-card"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["prepared-route-button"].exists)
        let fineTune = app.buttons["home-fine-tune-toggle"]
        XCTAssertTrue(fineTune.exists)
        XCTAssertFalse(app.descendants(matching: .any)["home-preference-card"].exists)
        fineTune.tap()
        XCTAssertTrue(app.descendants(matching: .any)["home-preference-card"].waitForExistence(timeout: 5))
    }

    func testFirstRouteTapAsksForNavigationAppAndRemembersSelection() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-navigation-picker"]
        app.launch()

        let routeButton = app.buttons["prepared-route-button"]
        XCTAssertTrue(routeButton.waitForExistence(timeout: 20))
        routeButton.tap()
        XCTAssertTrue(app.buttons["Apple Maps"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Google Maps"].exists)
        app.buttons["Google Maps"].tap()
        routeButton.tap()
        XCTAssertFalse(app.buttons["Apple Maps"].waitForExistence(timeout: 1))
    }

    func testProfileKeepsComplexSettingsCollapsedByDefault() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-profile"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["verified-outcome-value"].waitForExistence(timeout: 12))
        let automation = app.buttons["profile-automation-toggle"]
        XCTAssertTrue(automation.exists)
        XCTAssertFalse(app.switches["Benim için rota hazırla"].exists)
        automation.tap()
        XCTAssertTrue(app.switches["Benim için rota hazırla"].waitForExistence(timeout: 5))
    }

    func testManualLocationInputHidesWhenDeviceLocationIsAvailable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-device-location"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["home-screen"].waitForExistence(timeout: 12))
        XCTAssertFalse(app.descendants(matching: .any)["location-input"].exists)
    }

    func testLoungeOmitsRedundantPageTitle() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-lounge"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["lounge-screen"].waitForExistence(timeout: 12))
        XCTAssertFalse(app.staticTexts["Salon"].exists)
    }

    func testLoungeRotatesIntoFullscreenGame() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-lounge"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["lounge-screen"].waitForExistence(timeout: 12))
        for _ in 0..<5 where !app.buttons["lounge-fullscreen-button"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["lounge-fullscreen-button"].isHittable)
        app.buttons["lounge-fullscreen-button"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["lounge-game-fullscreen"].waitForExistence(timeout: 8))
        let exit = app.descendants(matching: .any)["lounge-fullscreen-exit"]
        XCTAssertTrue(exit.waitForExistence(timeout: 8))
        exit.tap()
        XCTAssertTrue(app.descendants(matching: .any)["lounge-screen"].waitForExistence(timeout: 8))
    }

    func testEnglishHeadingsUseLatinCapitalI() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-home-en"]
        app.launch()

        let fineTune = app.buttons["home-fine-tune-toggle"]
        XCTAssertTrue(fineTune.waitForExistence(timeout: 12))
        XCTAssertFalse(app.staticTexts["DRIVING PROFILE"].exists)
        fineTune.tap()
        XCTAssertTrue(app.staticTexts["DRIVING PROFILE"].waitForExistence(timeout: 12))
        XCTAssertFalse(app.staticTexts["DRİVİNG PROFİLE"].exists)
    }

    func testDrivingMetricsAlignAndExpandedPanelsRemainReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-home-en"]
        app.launch()

        let fineTune = app.buttons["home-fine-tune-toggle"]
        XCTAssertTrue(fineTune.waitForExistence(timeout: 12))
        fineTune.tap()
        let profile = app.buttons["driving-profile-toggle"]
        XCTAssertTrue(profile.waitForExistence(timeout: 12))
        profile.tap()

        let battery = app.descendants(matching: .any)["battery-capacity-input"]
        let consumption = app.descendants(matching: .any)["average-consumption-input"]
        XCTAssertTrue(battery.waitForExistence(timeout: 8))
        XCTAssertTrue(consumption.exists)
        XCTAssertEqual(battery.frame.minY, consumption.frame.minY, accuracy: 2)

        let filters = app.descendants(matching: .any)["filters-and-settings-toggle"]
        for _ in 0..<4 where !filters.isHittable { app.swipeUp() }
        XCTAssertTrue(filters.isHittable)
        filters.tap()
        let rangeToggle = app.switches["Hide out-of-range"]
        XCTAssertTrue(rangeToggle.waitForExistence(timeout: 8))
        for _ in 0..<3 where !rangeToggle.isHittable { app.swipeUp() }
        XCTAssertTrue(rangeToggle.isHittable)
    }

    func testHabitSuggestionAppearsAfterRepeatedUse() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-habit"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["home-screen"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.descendants(matching: .any)["habit-suggestion-card"].waitForExistence(timeout: 5))
    }

    func testAutonomousAgentPresentsPreparedRoute() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-agent"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["home-screen"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.descendants(matching: .any)["autonomous-proposal-card"].waitForExistence(timeout: 8))
    }

    func testCriticalRangeBecomesTheSinglePrimaryContext() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-context-critical"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["home-screen"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.descendants(matching: .any)["critical-range-context-card"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["habit-suggestion-card"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["autonomous-proposal-card"].exists)
    }

    func testStationStoryImageOpensShareSheet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-routes", "--ui-testing-story"]
        app.launch()

        let actionsMenu = app.descendants(matching: .any)["station-actions-menu"]
        XCTAssertTrue(actionsMenu.waitForExistence(timeout: 15))
        actionsMenu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let shareButton = app.buttons["Şarj noktasını paylaş"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 15))
        shareButton.tap()

        let preview = app.descendants(matching: .any)["station-story-preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 20))

        let confirmButton = app.buttons["station-story-confirm-share-button"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        let shareSheet = app.descendants(matching: .any)["ActivityListView"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 20))
    }

    func testRoutesTabAutomaticallyFindsStations() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-routes-idle"]
        app.launch()

        let routeCard = app.descendants(matching: .any)["station-route-card"]
        XCTAssertTrue(routeCard.waitForExistence(timeout: 15))
    }

    func testProfileCanOpenNavigationAndReturnHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-profile"]
        app.launch()

        let home = app.buttons["bottom-navigation-tab-home"]
        let routes = app.buttons["bottom-navigation-tab-routes"]
        let lounge = app.buttons["bottom-navigation-tab-lounge"]
        let profile = app.buttons["bottom-navigation-tab-account"]
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        XCTAssertTrue(routes.exists)
        XCTAssertTrue(lounge.exists)
        XCTAssertTrue(profile.exists)
        XCTAssertLessThan(home.frame.minX, routes.frame.minX)
        XCTAssertLessThan(routes.frame.minX, lounge.frame.minX)
        XCTAssertLessThan(lounge.frame.minX, profile.frame.minX)
        home.tap()

        XCTAssertTrue(app.descendants(matching: .any)["home-screen"].waitForExistence(timeout: 10))
    }

    func testBackButtonAppearsOnlyOnProfileAndReturnsHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-profile"]
        app.launch()

        let profileBack = app.buttons["profile-back-button"]
        XCTAssertTrue(profileBack.waitForExistence(timeout: 10))
        profileBack.tap()

        XCTAssertTrue(app.descendants(matching: .any)["home-screen"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["profile-back-button"].exists)
    }

    func testBundledStationCatalogCreatesRoute() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-device-location"]
        app.launch()

        let preparedCard = app.descendants(matching: .any)["prepared-route-card"]
        XCTAssertTrue(preparedCard.waitForExistence(timeout: 20))
        app.buttons["prepared-route-alternatives"].tap()

        let routeCard = app.descendants(matching: .any)["station-route-card"]
        XCTAssertTrue(routeCard.waitForExistence(timeout: 20))
    }

    func testSearchRecoversFromFiltersThatWouldHideEveryStation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-filter-recovery"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["prepared-route-card"].waitForExistence(timeout: 20))
        app.buttons["prepared-route-alternatives"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["station-route-card"].waitForExistence(timeout: 15))
    }

    func testOutsideCoverageRevealsLocationRecoveryInsteadOfEmptyRoutes() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-outside-coverage"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["home-screen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["location-input"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.descendants(matching: .any)["station-route-card"].exists)
    }
}
