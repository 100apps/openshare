import UIKit
#if canImport(OpenShareCore)
import OpenShareCore
#endif

@MainActor public final class PublicLinkProvider: ShareProvider {
    public enum Service: String { case telegram, whatsapp }
    public let service: Service
    public var id: String { service.rawValue }
    public var lane: String? { nil }
    public init(_ service: Service) { self.service = service }
    public func link(for request: ShareRequest) throws -> URL {
        try request.validate()
        guard case .share(_, let channel, let content) = request else { throw ShareError.unsupportedOperation }
        guard channel == "default" else { throw ShareError.unsupportedChannel }
        var query: [URLQueryItem]
        switch (service, content) {
        case (.whatsapp, .text(let text)): query = [URLQueryItem(name: "text", value: text)]
        case (_, .link(let url, let title, let summary)):
            guard title == nil, summary == nil else { throw ShareError.unsupportedField }
            query = [URLQueryItem(name: service == .telegram ? "url" : "text", value: url.absoluteString)]
        default: throw ShareError.unsupportedContent
        }
        var url = URLComponents(string: service == .telegram ? "https://t.me/share/url" : "https://wa.me/")!
        url.queryItems = query
        // Form-style decoders used by web entry points treat a literal '+' as a space.
        url.percentEncodedQuery = url.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return url.url!
    }
    public func prepare(_ request: ShareRequest) throws -> ShareCapabilities {
        _ = try link(for: request)
        return ShareCapabilities(outcomes: [.handedOff], correlation: .requestBound)
    }
    public func start(_ request: ShareRequest, context: AnyObject, operation: ShareOperation) {
        guard let presentation = context as? SharePresentation, presentation.isValid else {
            operation.fail(.invalidPresenter); return
        }
        guard let url = try? link(for: request) else { operation.fail(.invalidContent); return }
        UIApplication.shared.open(url, options: [:]) { accepted in
            MainActor.assumeIsolated {
                if accepted { operation.complete(.handedOff) } else { operation.fail(.dispatchRejected) }
            }
        }
    }
}
