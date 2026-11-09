// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenShare",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "OpenShare", targets: ["OpenShare"]),
        .library(name: "OpenShareCore", targets: ["OpenShareCore"]),
        .library(name: "OpenShareNext", targets: ["OpenShareSystem"])
    ],
    targets: [
        .target(name: "OpenShare", path: "openshare", publicHeadersPath: ".",
                linkerSettings: [.linkedFramework("UIKit"), .linkedFramework("WebKit")]),
        .target(name: "OpenShareCore", path: "next/ios/Core"),
        .target(name: "OpenShareSystem", dependencies: ["OpenShareCore"], path: "next/ios/System",
                linkerSettings: [.linkedFramework("UIKit")])
    ]
)
