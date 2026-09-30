import XCTest

@MainActor
final class AppearanceUITests: XCTestCase {
    func testAppearanceSelectionPersistsAcrossNavigationAndRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-home"]
        app.launch()
        app.buttons["bottom-navigation-tab-account"].tap()

        let lightOption = app.buttons["appearance-option-lightAnthracite"]
        XCTAssertTrue(lightOption.waitForExistence(timeout: 10))
        lightOption.tap()
        XCTAssertEqual(lightOption.value as? String, "Seçili")

        app.buttons["bottom-navigation-tab-home"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["prepared-route-card"].waitForExistence(timeout: 20))
        app.buttons["bottom-navigation-tab-account"].tap()
        XCTAssertEqual(lightOption.value as? String, "Seçili")

        app.terminate()
        app.launchArguments = ["--ui-testing-home", "--ui-testing-preserve-settings"]
        app.launch()
        app.buttons["bottom-navigation-tab-account"].tap()
        XCTAssertTrue(lightOption.waitForExistence(timeout: 10))
        XCTAssertEqual(lightOption.value as? String, "Seçili")

        let darkOption = app.buttons["appearance-option-dark"]
        darkOption.tap()
        XCTAssertEqual(darkOption.value as? String, "Seçili")
        XCTAssertEqual(lightOption.value as? String, "Seçili değil")
    }

    func testCaptureLightAppearanceScreens() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        let screens = [
            ("light-home", "--ui-testing-home", "prepared-route-card"),
            ("light-routes", "--ui-testing-routes", "station-route-card"),
            ("light-account", "--ui-testing-profile", "appearance-picker"),
            ("light-suggestion", "--ui-testing-agent", "autonomous-proposal-card")
        ]
        for (name, argument, identifier) in screens {
            app.launchArguments = [argument, "--ui-testing-light-appearance", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)[identifier].waitForExistence(timeout: 30))
            capture(name)
            if name == "light-home" {
                app.buttons["home-fine-tune-toggle"].tap()
                let profile = app.buttons["driving-profile-toggle"]
                XCTAssertTrue(profile.waitForExistence(timeout: 10))
                app.swipeUp()
                profile.tap()
                XCTAssertTrue(app.textFields["battery-capacity-input"].waitForExistence(timeout: 10))
                app.swipeUp()
                capture("light-driving-profile")
            }
            app.terminate()
        }
    }

    private func capture(_ name: String) {
        // Allow scrolling, appearance changes and map tiles to settle for visual review.
        Thread.sleep(forTimeInterval: 3)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "appearance-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
