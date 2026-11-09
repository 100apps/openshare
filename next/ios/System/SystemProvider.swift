import UIKit
#if canImport(OpenShareCore)
import OpenShareCore
#endif

@MainActor public final class SharePresentation {
    public weak var controller: UIViewController?
    public weak var sourceView: UIView?
    public init(_ controller: UIViewController, sourceView: UIView) {
        self.controller = controller; self.sourceView = sourceView
    }
    public var isValid: Bool {
        guard let controller, let sourceView, let window = controller.viewIfLoaded?.window,
              window.windowScene?.activationState == .foregroundActive,
              !controller.isBeingDismissed, !controller.isBeingPresented,
              controller.presentedViewController == nil else { return false }
        return sourceView === controller.view || sourceView.isDescendant(of: controller.view)
    }
}

@MainActor public final class SystemShareProvider: ShareProvider {
    public let id = "system"
    public var lane: String? { nil }
    public init() {}
    public func prepare(_ request: ShareRequest) throws -> ShareCapabilities {
        guard case .share(_, let channel, let content) = request else { throw ShareError.unsupportedOperation }
        guard channel == "default" else { throw ShareError.unsupportedChannel }
        _ = try items(content)
        return ShareCapabilities(outcomes: [.activityCompleted, .notCompleted], correlation: .requestBound)
    }
    private func items(_ content: ShareContent) throws -> [Any] {
        var result: [Any] = []
        switch content {
        case .text(let text): return [text]
        case .link(let url, let title, let summary):
            if let title { result.append(title) }
            if let summary { result.append(summary) }
            result.append(url)
            return result
        case .images(let urls, let caption): result = urls; if let caption { result.append(caption) }
        case .video(let url, let caption): result = [url]; if let caption { result.append(caption) }
        case .file(let url): result = [url]
        }
        for case let url as URL in result {
            guard url.isFileURL, (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                  FileManager.default.isReadableFile(atPath: url.path) else {
                throw ShareError.resourceUnavailable
            }
        }
        return result
    }
    public func start(_ request: ShareRequest, context: AnyObject, operation: ShareOperation) {
        guard let presentation = context as? SharePresentation, presentation.isValid,
              let controller = presentation.controller, let source = presentation.sourceView,
              case .share(_, _, let content) = request else { operation.fail(.invalidPresenter); return }
        do {
            let sheet = UIActivityViewController(activityItems: try items(content), applicationActivities: nil)
            sheet.popoverPresentationController?.sourceView = source
            sheet.popoverPresentationController?.sourceRect = source.bounds
            sheet.completionWithItemsHandler = { _, completed, _, error in
                MainActor.assumeIsolated {
                    if error != nil { operation.fail(.providerError) }
                    else { operation.complete(completed ? .activityCompleted : .notCompleted) }
                }
            }
            controller.present(sheet, animated: true)
        } catch { operation.fail(.resourceUnavailable) }
    }
}
