import XCTest
import OpenShare

final class SwiftInteropTests: XCTestCase {
    func testSystemSharingIsAvailableToSwiftClients() throws {
        let message = OSMessage()
        message.title = "你好 OpenShare"
        let items = try OpenShare.systemActivityItems(for: message)
        XCTAssertEqual(items.first as? String, "你好 OpenShare")
    }
}
