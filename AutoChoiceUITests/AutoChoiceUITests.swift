import XCTest

final class AutoChoiceUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testScreenshots() {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-FASTLANE_SNAPSHOT", "YES", "-ui_testing"]
        app.launch()
        sleep(2)

        snapshot("01-Wheel")

        let spin = app.buttons["Spin"]
        if spin.waitForExistence(timeout: 5) {
            spin.tap()
            sleep(4)
            snapshot("02-Result")
        }

        let leftToolbar = app.navigationBars.buttons.element(boundBy: 0)
        if leftToolbar.waitForExistence(timeout: 5) {
            leftToolbar.tap()
            sleep(1)
            snapshot("03-Lists")
            let done = app.buttons["Done"]
            if done.exists { done.tap(); sleep(1) }
        }

        let menu = app.navigationBars.buttons.element(boundBy: app.navigationBars.buttons.count - 1)
        if menu.waitForExistence(timeout: 5) {
            menu.tap()
            sleep(1)
            let settings = app.buttons["Settings"]
            if settings.exists {
                settings.tap()
                sleep(1)
                snapshot("04-Settings")
                let done = app.buttons["Done"]
                if done.exists { done.tap(); sleep(1) }
            }
        }

        if menu.exists {
            menu.tap()
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
