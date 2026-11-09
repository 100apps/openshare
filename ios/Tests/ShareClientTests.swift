import XCTest
import UIKit
@testable import OpenShareCore
import OpenShareSystem
import OpenShareWeChat

@MainActor private final class FakeProvider: ShareProvider {
    let id: String
    var callbackKeys: Set<String> = []
    var correlation: ShareCorrelation = .requestBound
    var pending: ShareOperation?
    var starts = 0
    init(id: String = UUID().uuidString) { self.id = id }
    func prepare(_ request: ShareRequest) throws -> ShareCapabilities {
        let outcome: ShareOutcome
        if case .authorize = request { outcome = .credentialReceived } else { outcome = .handedOff }
        return ShareCapabilities(outcomes: [outcome], correlation: correlation)
    }
    func start(_ request: ShareRequest, context: AnyObject, operation: ShareOperation) { starts += 1; pending = operation }
}

final class ShareClientTests: XCTestCase {
    @MainActor func testSharedContractFixturesAndEncoding() throws {
        let telegram = PublicLinkProvider(.telegram), whatsapp = PublicLinkProvider(.whatsapp)
        let client = try ShareClient(providers: [SystemShareProvider(), telegram, whatsapp])
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "contracts", withExtension: "json"))
        let cases = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
        for c in cases {
            let provider = c["provider"] as! String
            let content: ShareContent
            if c["kind"] as? String == "link" {
                content = .link(URL(string: c["url"] as! String)!, title: c["title"] as? String, summary: c["summary"] as? String)
            } else { content = .text(c["text"] as? String ?? "") }
            let request: ShareRequest = c["auth"] as? Bool == true ?
                .authorize(provider: provider, scope: c["scope"] as! String) :
                .share(provider: provider, channel: c["channel"] as? String ?? "default", content: content)
            if let error = c["error"] as? String {
                XCTAssertThrowsError(try client.prepare(request), c["name"] as! String) { XCTAssertEqual(($0 as? ShareError)?.rawValue, error) }
            } else {
                XCTAssertTrue(try client.prepare(request).capabilities.outcomes.contains(ShareOutcome(rawValue: c["iosOutcome"] as! String)!))
                if provider != "system" {
                    let link = try (provider == "telegram" ? telegram : whatsapp).link(for: request)
                    let parameter = URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems?.first?.value
                    XCTAssertEqual(parameter, c[c["kind"] as? String == "link" ? "url" : "text"] as? String)
                    XCTAssertFalse(URLComponents(url: link, resolvingAgainstBaseURL: false)!.percentEncodedQuery!.contains("+"))
                }
            }
        }
    }
    @MainActor func testCancellationAndTimeoutRetainLaneUntilRealResponse() async throws {
        for timeout in [false, true] {
            let provider = FakeProvider()
            let first = try ShareClient(providers: [provider]), second = try ShareClient(providers: [provider])
            let request = ShareRequest.share(provider: provider.id, content: .text("hello"))
            let done = expectation(description: "two caller results"); done.expectedFulfillmentCount = 2
            var results: [ShareResult] = []
            let callback: (ShareResult) -> Void = { results.append($0); done.fulfill() }
            let old = try first.execute(request, context: NSObject(), completion: callback)
            if timeout { old.expire() } else { old.cancel() }
            XCTAssertEqual(old.result?.outcome, timeout ? .indeterminate : .cancelledLocally)
            XCTAssertThrowsError(try second.execute(request, context: NSObject(), completion: callback)) { XCTAssertEqual($0 as? ShareError, .busy) }
            old.complete(.handedOff)
            let next = try second.execute(request, context: NSObject(), completion: callback)
            old.fail(.providerError)
            XCTAssertNil(next.result)
            next.complete(.handedOff)
            await fulfillment(of: [done], timeout: 2)
            XCTAssertEqual(results.count, 2)
            XCTAssertEqual(results.first?.outcome, old.result?.outcome)
        }
    }
    @MainActor func testCredentialKindsAndSensitiveDescriptions() throws {
        let provider = FakeProvider(), credential = try ShareCredential(kind: .authorizationCode, value: "private-code")
        let client = try ShareClient(providers: [provider])
        let request = ShareRequest.authorize(provider: provider.id, scope: "profile")
        let wrong = try client.execute(request, context: NSObject()) { _ in }
        wrong.complete(.credentialReceived, credential: try ShareCredential(kind: .accessToken, value: "private-token"))
        XCTAssertEqual(wrong.result?.error, .invalidResponse)
        let valid = try client.execute(request, context: NSObject()) { _ in }
        valid.complete(.credentialReceived, credential: credential)
        XCTAssertEqual(valid.result?.outcome, .credentialReceived)
        XCTAssertEqual(valid.result?.credential?.value, credential.value)
        XCTAssertFalse(String(describing: credential).contains("private-code"))
        XCTAssertFalse(String(reflecting: valid.result).contains("private-code"))
        XCTAssertThrowsError(try ShareCredential(kind: .identityToken, value: " "))
    }
    @MainActor func testRegistrationIsAtomicAndCallbackOwnershipIsExclusive() throws {
        let one = FakeProvider(), two = FakeProvider()
        one.callbackKeys = ["scheme:\(UUID().uuidString)"]; two.callbackKeys = one.callbackKeys
        XCTAssertThrowsError(try ShareClient(providers: [one, two]))
        let owner = try ShareClient(providers: [one])
        XCTAssertNotNil(try owner.prepare(.share(provider: one.id, content: .text("hello"))))
        XCTAssertThrowsError(try ShareClient(providers: [two]))
        XCTAssertNotNil(try ShareClient(providers: [one]))
        XCTAssertThrowsError(try ShareClient(providers: [one, one]))
        XCTAssertFalse(owner.handleCallback(URL(string: "unknown://callback")!))
    }
    @MainActor func testPlanOwnershipAndRequiredGuarantees() throws {
        let provider = FakeProvider(), client = try ShareClient(providers: [provider])
        let request = ShareRequest.share(provider: provider.id, content: .text("hello"))
        XCTAssertThrowsError(try client.prepare(request, requiring: .sdkReportedSuccess))
        provider.correlation = .serializedOnly
        XCTAssertThrowsError(try client.prepare(request, requestBound: true))
        let plan = try client.prepare(request)
        let foreign = try ShareClient(providers: [FakeProvider(id: provider.id)])
        XCTAssertThrowsError(try foreign.execute(plan, context: NSObject()) { _ in })
        provider.correlation = .requestBound
        XCTAssertThrowsError(try client.execute(plan, context: NSObject()) { _ in })
        XCTAssertEqual(provider.starts, 0)
    }
    @MainActor func testFilesAreRecheckedAndInvalidPresenterDoesNotDispatch() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("attachment".utf8).write(to: file)
        let client = try ShareClient(providers: [SystemShareProvider()])
        let plan = try client.prepare(.share(provider: "system", content: .file(file)))
        try FileManager.default.removeItem(at: file)
        XCTAssertThrowsError(try client.execute(plan, context: NSObject()) { _ in }) { XCTAssertEqual($0 as? ShareError, .resourceUnavailable) }
        XCTAssertThrowsError(try client.prepare(.share(provider: "system", content: .images([]))))
        let operation = try client.execute(.share(provider: "system", content: .text("hello")), context: NSObject()) { _ in }
        XCTAssertEqual(operation.result?.error, .invalidPresenter)
    }
    @MainActor func testWeChatPreflightDoesNotRegisterSDKOrOverstateCorrelation() throws {
        let wechat = try WeChatProvider(appID: "wx-next-test", universalLink: URL(string: "https://example.com/wx/")!)
        let client = try ShareClient(providers: [wechat])
        let share = ShareRequest.share(provider: "wechat", channel: "session", content: .text("hello"))
        XCTAssertEqual(try client.prepare(share).capabilities.correlation, .serializedOnly)
        XCTAssertThrowsError(try client.prepare(share, requestBound: true))
        XCTAssertThrowsError(try client.prepare(.authorize(provider: "wechat", scope: "profile", credential: .accessToken)))
        XCTAssertEqual(try client.prepare(.authorize(provider: "wechat", scope: "profile")).capabilities.correlation, .requestBound)
        XCTAssertFalse(client.handleCallback(URL(string: "wx-next-test://oauth?code=orphan")!))
    }
}
