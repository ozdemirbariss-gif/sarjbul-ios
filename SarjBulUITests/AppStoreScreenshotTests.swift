import XCTest

/// Capture the shipping UI and real station repository, without Debug fixtures.
/// Run only through Scripts/capture_app_store.sh, which builds in Release.
@MainActor
final class AppStoreScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        #if DEBUG
        throw XCTSkip("App Store captures require the Release build and a configured simulator.")
        #endif
    }

    func testCaptureTurkish() throws {
        try capture(language: "tr", locale: "tr_TR", storeLocale: "tr")
    }

    func testCaptureEnglish() throws {
        try capture(language: "en", locale: "en_US", storeLocale: "en-US")
    }

    private func capture(language: String, locale: String, storeLocale: String) throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        // These are normal UserDefaults preferences, not application test modes.
        // Ignore a reminder left by an earlier capture in this dedicated simulator.
        app.launchArguments = [
            "-AppleLanguages", "(\(language))", "-AppleLocale", locale,
            "-appLanguage", language, "-appAppearance", "dark",
            "-activeChargingSession", ""
        ]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["prepared-route-button"].waitForExistence(timeout: 90))
        save("01-home", locale: storeLocale)

        app.buttons["bottom-navigation-tab-routes"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["station-route-card"].firstMatch
            .waitForExistence(timeout: 60))
        save("04-route", locale: storeLocale)

        app.buttons[language == "tr" ? "Harita" : "Map"].tap()
        save("02-stations-map", locale: storeLocale, settle: 12)

        app.buttons["station-filters-button"].tap()
        let apply = app.buttons["station-filters-apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 10))
        // Scroll the shipping medium sheet to its power, connector and range controls.
        app.swipeUp()
        save("03-filters", locale: storeLocale)
        apply.tap()

        app.buttons[language == "tr" ? "Kartlar" : "Cards"].tap()
        let tools = app.descendants(matching: .any)["station-actions-menu"].firstMatch
        XCTAssertTrue(tools.waitForExistence(timeout: 30))
        tools.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let reminder = app.buttons[language == "tr"
            ? "30 dk şarj hatırlatıcısı kur" : "Set a 30 min charging reminder"]
        XCTAssertTrue(reminder.waitForExistence(timeout: 10))
        reminder.tap()
        XCTAssertTrue(app.descendants(matching: .any)["active-charging-context-card"]
            .waitForExistence(timeout: 20))
        save("05-charging-break", locale: storeLocale)
    }

    private func save(_ name: String, locale: String, settle: Double = 4) {
        Thread.sleep(forTimeInterval: settle)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "app-store-\(locale)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
