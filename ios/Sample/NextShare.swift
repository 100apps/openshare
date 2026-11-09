import UIKit
import OpenShareCore
import OpenShareSystem

@MainActor @objc(OSNextShare) final class OSNextShare: NSObject {
    private static let client = try! ShareClient(providers: [SystemShareProvider()])
    @objc(shareFrom:sourceView:) static func share(from controller: UIViewController, sourceView: UIView) {
        do {
            try client.execute(.share(provider: "system", content: .link(URL(string: "https://github.com/100apps/openshare")!, title: "OpenShare")),
                               context: SharePresentation(controller, sourceView: sourceView)) { _ in }
        } catch {
            let alert = UIAlertController(title: "Share unavailable", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            controller.present(alert, animated: true)
        }
    }
}
