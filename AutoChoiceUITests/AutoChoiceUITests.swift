import XCTest

final class AutoChoiceUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testScreenshots() {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        // Onboarding is auto-skipped because the app detects -FASTLANE_SNAPSHOT.
        // Wait for the main screen to settle.
        XCTAssertTrue(app.staticTexts["What to eat?"].waitForExistence(timeout: 10))

        // 1) Main screen with the wheel.
        snapshot("01-Wheel")

        // 2) Spin → result banner.
        let spin = app.buttons["Spin"]
        if spin.exists { spin.tap() }
        // Wheel animation runs ~3.5s; result banner appears after.
        sleep(4)
        snapshot("02-Result")

        // 3) Lists sheet.
        let listsButton = app.navigationBars.buttons.element(boundBy: 0)
        if listsButton.exists {
            listsButton.tap()
            sleep(1)
            snapshot("03-Lists")
            // Close
            let done = app.buttons["Done"]
            if done.exists { done.tap() }
        }

        // 4) Settings sheet via overflow menu.
        let menuButton = app.navigationBars.buttons.element(boundBy: app.navigationBars.buttons.count - 1)
        if menuButton.exists {
            menuButton.tap()
            sleep(1)
            let settings = app.buttons["Settings"]
            if settings.exists {
                settings.tap()
                sleep(1)
                snapshot("04-Settings")
                let done = app.buttons["Done"]
                if done.exists { done.tap() }
            }
        }

        // 5) Paywall via overflow menu.
        if menuButton.exists {
            menuButton.tap()
            sleep(1)
            let goPremium = app.buttons["Go Premium"]
            if goPremium.exists {
                goPremium.tap()
                sleep(1)
                snapshot("05-Paywall")
            }
        }
    }
}
