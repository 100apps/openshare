import XCTest
import UIKit
import WechatOpenSDK
import OpenShareCore
import OpenShareSystem
import OpenShareWeChat

final class WeChatProviderTests: XCTestCase {
    @MainActor private func context() throws -> SharePresentation {
        let controller = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController)
        return SharePresentation(controller, sourceView: controller.view)
    }
    @MainActor func testAuthUsesRealSDKTypesAndChecksStateBeforeDeliveringCode() async throws {
        OSWXStubBegin(); defer { OSWXStubEnd() }
        let provider = try WeChatProvider(appID: "wx-next-auth", universalLink: URL(string: "https://example.com/wx/")!)
        let client = try ShareClient(providers: [provider])
        let done = expectation(description: "validated credential")
        let op = try client.execute(.authorize(provider: "wechat", scope: "profile"), context: context()) { result in
            XCTAssertEqual(result.outcome, .credentialReceived)
            XCTAssertEqual(result.credential?.kind, .authorizationCode)
            XCTAssertEqual(result.credential?.value, "server-exchange-code")
            done.fulfill()
        }
        let request = try XCTUnwrap(OSWXStubRequest() as? SendAuthReq)
        XCTAssertFalse(request.state.isEmpty)
        XCTAssertNil(op.result, "SDK dispatch acceptance must not complete authorization")
        let wrong = SendAuthResp(); wrong.state = "unrelated"; wrong.code = "wrong"
        provider.onResp(wrong)
        let correct = SendAuthResp(); correct.state = request.state; correct.code = "server-exchange-code"
        provider.onResp(correct); provider.onResp(correct)
        await fulfillment(of: [done], timeout: 2)
        XCTAssertEqual(op.result?.correlation, .requestBound)
    }
    @MainActor func testShareCancellationAndDispatchRejectionAreDifferent() async throws {
        OSWXStubBegin(); defer { OSWXStubEnd() }
        let provider = try WeChatProvider(appID: "wx-next-share", universalLink: URL(string: "https://example.com/wx/")!)
        let client = try ShareClient(providers: [provider])
        let request = ShareRequest.share(provider: "wechat", channel: "timeline", content: .link(URL(string: "https://example.com/")!, title: "title"))
        let cancelled = expectation(description: "external cancel")
        let op = try client.execute(request, context: context()) { result in
            XCTAssertEqual(result.outcome, .cancelledByUser)
            XCTAssertEqual(result.correlation, .serializedOnly)
            cancelled.fulfill()
        }
        XCTAssertEqual((OSWXStubRequest() as? SendMessageToWXReq)?.scene, 1)
        XCTAssertNil(op.result)
        XCTAssertFalse(client.handleCallback(URL(string: "https://example.com/wx-evil/callback")!))
        let response = SendMessageToWXResp(); response.errCode = -2; provider.onResp(response)
        await fulfillment(of: [cancelled], timeout: 2)
        OSWXStubSetAccepted(false)
        let failed = expectation(description: "dispatch rejected")
        try client.execute(request, context: context()) { result in
            XCTAssertEqual(result.error, .dispatchRejected); failed.fulfill()
        }
        await fulfillment(of: [failed], timeout: 2)
    }
}
