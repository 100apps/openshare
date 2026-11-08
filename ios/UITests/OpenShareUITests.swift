import XCTest

final class OpenShareUITests: XCTestCase {
    @MainActor
    func testSystemShareSheetDisplaysLinkAndCompletesCopy() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        defer {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            app.terminate()
        }
        let button = app.buttons["openshare.share"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertFalse(sheet.exists)
        button.tap()
        XCTAssertTrue(sheet.waitForExistence(timeout: 15))
        let linkPreview = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "github.com")
        ).firstMatch
        XCTAssertTrue(linkPreview.waitForExistence(timeout: 10))
        let copy = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Copy")
        ).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
        copy.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed)
    }
}
