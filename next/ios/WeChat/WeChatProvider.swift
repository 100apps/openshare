import UIKit
import WechatOpenSDK
#if canImport(OpenShareCore)
import OpenShareCore
#endif
#if canImport(OpenShareSystem)
import OpenShareSystem
#endif

/// Optional official SDK provider. Registration is deferred until the first explicit operation.
@MainActor public final class WeChatProvider: NSObject, ShareProvider, WXApiDelegate {
    public let id = "wechat"
    public var callbackKeys: Set<String> { ["sdk:wechat", "scheme:\(appID.lowercased())"] }
    private let appID: String
    private let universalLink: URL
    private var registered = false
    private var pending: (operation: ShareOperation, auth: Bool, state: String)?

    public init(appID: String, universalLink: URL) throws {
        guard !appID.isEmpty, universalLink.scheme == "https", universalLink.host?.isEmpty == false,
              universalLink.absoluteString.hasSuffix("/"), universalLink.query == nil,
              universalLink.fragment == nil, universalLink.user == nil, universalLink.password == nil else {
            throw ShareError.invalidContent
        }
        self.appID = appID; self.universalLink = universalLink
        super.init()
    }
    public func prepare(_ request: ShareRequest) throws -> ShareCapabilities {
        switch request {
        case .authorize(_, _, let kind):
            guard kind == .authorizationCode else { throw ShareError.unsupportedCredentialKind }
            return ShareCapabilities(outcomes: [.credentialReceived, .cancelledByUser], correlation: .requestBound)
        case .share(_, let channel, let content):
            _ = try scene(channel)
            switch content { case .text, .link: break; default: throw ShareError.unsupportedContent }
            return ShareCapabilities(outcomes: [.sdkReportedSuccess, .cancelledByUser], correlation: .serializedOnly)
        }
    }
    private func scene(_ channel: String) throws -> Int32 {
        switch channel {
        case "default", "session": return 0
        case "timeline": return 1
        case "favorite": return 2
        default: throw ShareError.unsupportedChannel
        }
    }
    public func start(_ request: ShareRequest, context: AnyObject, operation: ShareOperation) {
        guard let presentation = context as? SharePresentation, presentation.isValid else {
            operation.fail(.invalidPresenter); return
        }
        guard pending == nil else { operation.fail(.busy); return }
        if !registered {
            registered = WXApi.registerApp(appID, universalLink: universalLink.absoluteString)
        }
        guard registered else { operation.fail(.configurationConflict); return }
        guard WXApi.isWXAppInstalled() else { operation.fail(.providerUnavailable); return }
        let native: BaseReq
        let state = UUID().uuidString
        switch request {
        case .authorize(_, let scope, _):
            let auth = SendAuthReq(); auth.scope = scope; auth.state = state
            native = auth
            pending = (operation, true, state)
        case .share(_, let channel, let content):
            guard let target = try? scene(channel) else { operation.fail(.unsupportedChannel); return }
            let share = SendMessageToWXReq(); share.scene = target
            switch content {
            case .text(let text): share.bText = true; share.text = text
            case .link(let url, let title, let summary):
                let page = WXWebpageObject(); page.webpageUrl = url.absoluteString
                let message = WXMediaMessage(); message.mediaObject = page
                if let title { message.title = title }
                if let summary { message.description = summary }
                share.message = message
            default: operation.fail(.unsupportedContent); return
            }
            native = share
            pending = (operation, false, state)
        }
        WXApi.send(native) { [weak self] accepted in
            Task { @MainActor in
                guard let self, !accepted, self.pending?.operation === operation else { return }
                self.pending = nil; operation.fail(.dispatchRejected)
            }
        }
    }
    public func handleCallback(_ url: URL) -> Bool {
        guard pending != nil else { return false }
        if url.scheme?.lowercased() == appID.lowercased() { return WXApi.handleOpen(url, delegate: self) }
        guard let route = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let base = URLComponents(url: universalLink, resolvingAgainstBaseURL: false),
              url.scheme == "https", url.host?.lowercased() == universalLink.host?.lowercased(),
              url.port == universalLink.port, url.user == nil, url.password == nil,
              route.percentEncodedPath.hasPrefix(base.percentEncodedPath) else { return false }
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = url
        return WXApi.handleOpenUniversalLink(activity, delegate: self)
    }
    nonisolated public func onReq(_ req: BaseReq) {}
    nonisolated public func onResp(_ resp: BaseResp) {
        let auth = resp as? SendAuthResp
        let isAuth = auth != nil
        let isShare = resp is SendMessageToWXResp
        let state = auth?.state, code = auth?.code, errorCode = Int(resp.errCode)
        Task { @MainActor in self.receive(isAuth: isAuth, isShare: isShare, state: state, code: code, errorCode: errorCode) }
    }
    private func receive(isAuth: Bool, isShare: Bool, state: String?, code: String?, errorCode: Int) {
        guard let pending, pending.auth ? (isAuth && state == pending.state) : isShare else { return }
        self.pending = nil
        if errorCode != 0 {
            pending.operation.complete(errorCode == -2 ? .cancelledByUser : .failed,
                                       error: errorCode == -2 ? nil : .providerError, providerCode: errorCode)
        } else if pending.auth {
            guard let credential = try? ShareCredential(kind: .authorizationCode, value: code ?? "") else {
                pending.operation.fail(.invalidResponse); return
            }
            pending.operation.complete(.credentialReceived, credential: credential)
        } else { pending.operation.complete(.sdkReportedSuccess) }
    }
}
