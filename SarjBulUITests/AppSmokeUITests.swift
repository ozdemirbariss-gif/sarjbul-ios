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

    func testStationStoryImageOpensShareSheet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-routes", "--ui-testing-story"]
        app.launch()

        let shareButton = app.buttons.matching(identifier: "station-story-share-button").firstMatch
        XCTAssertTrue(shareButton.waitForExistence(timeout: 15))
        shareButton.tap()

        let shareSheet = app.otherElements["station-story-share-sheet"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 20))
    }
}
