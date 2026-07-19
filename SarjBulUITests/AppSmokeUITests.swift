import XCTest

@MainActor
final class AppSmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGuestCanReachHome() throws {
        let app = XCUIApplication()
        app.launch()

        let guestButton = app.buttons["guest-start-button"]
        XCTAssertTrue(guestButton.waitForExistence(timeout: 8))
        guestButton.tap()

        XCTAssertTrue(app.buttons["find-stations-button"].waitForExistence(timeout: 8))
    }

    func testHomeLaunchModeLoadsStationData() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-home"]
        app.launch()

        XCTAssertTrue(app.buttons["find-stations-button"].waitForExistence(timeout: 12))
    }
}
