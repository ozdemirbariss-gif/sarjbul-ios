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

    func testManualLocationInputHidesWhenDeviceLocationIsAvailable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-device-location"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["home-screen"].waitForExistence(timeout: 12))
        XCTAssertFalse(app.descendants(matching: .any)["location-input"].exists)
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

    func testStationStoryImageOpensShareSheet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-routes", "--ui-testing-story"]
        app.launch()

        let shareButton = app.buttons.matching(identifier: "station-story-share-button").firstMatch
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
}
