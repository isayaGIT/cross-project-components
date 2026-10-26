// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenMiniature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ScreenMiniature", targets: ["ScreenMiniature"])
    ],
    targets: [
        .target(name: "ScreenMiniature", path: "Sources/ScreenMiniature"),
        .testTarget(name: "ScreenMiniatureTests", dependencies: ["ScreenMiniature"], path: "Tests/ScreenMiniatureTests")
    ]
)
