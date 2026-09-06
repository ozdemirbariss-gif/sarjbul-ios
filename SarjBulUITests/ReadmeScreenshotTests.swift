import XCTest

@MainActor
final class ReadmeScreenshotTests: XCTestCase {
    func testCaptureReadmeScreens() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        let screens = [
            ("home", "--ui-testing-home", "prepared-route-card"),
            ("routes", "--ui-testing-routes", "station-route-card"),
            ("lounge", "--ui-testing-lounge", "lounge-screen"),
            ("account", "--ui-testing-profile", "verified-outcome-value"),
            ("arrival-outcome", "--ui-testing-arrived", "arrived-start-charging-card"),
            ("charging-suggestion", "--ui-testing-agent", "autonomous-proposal-card"),
            ("charging-suggestion-en", "--ui-testing-agent", "autonomous-proposal-card")
        ]
        for (name, argument, identifier) in screens {
            app.launchArguments = [argument, "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
            if name == "charging-suggestion-en" { app.launchArguments.append("--ui-testing-home-en") }
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)[identifier].waitForExistence(timeout: 30))
            // Let the entrance animations and native map tiles settle before capture.
            Thread.sleep(forTimeInterval: 5)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "readme-\(name)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }

        app.launchArguments = ["--ui-testing-routes", "--ui-testing-story"]
        app.launch()
        let menu = app.descendants(matching: .any)["station-actions-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let share = app.buttons["Şarj noktasını paylaş"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        XCTAssertTrue(app.descendants(matching: .any)["station-story-preview"].waitForExistence(timeout: 40))
    }
}
