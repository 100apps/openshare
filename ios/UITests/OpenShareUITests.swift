import XCTest

final class OpenShareUITests: XCTestCase {
    @MainActor
    func testSystemShareSheetDisplaysMessage() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        let button = app.buttons["openshare.share"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        let sharedContent = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "OpenShare")
        ).firstMatch
        XCTAssertFalse(sharedContent.exists)
        button.tap()
        XCTAssertTrue(sharedContent.waitForExistence(timeout: 15))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
