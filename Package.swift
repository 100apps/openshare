// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenShare",
    platforms: [.iOS(.v15)],
    products: [.library(name: "OpenShare", targets: ["OpenShare"])],
    targets: [
        .target(name: "OpenShare", path: "openshare", publicHeadersPath: ".",
                linkerSettings: [.linkedFramework("UIKit"), .linkedFramework("WebKit")])
    ]
)
