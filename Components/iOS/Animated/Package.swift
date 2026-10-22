// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Animated",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Animated", targets: ["Animated"])],
    targets: [
        .target(name: "Animated", path: "Sources/Animated"),
        .testTarget(name: "AnimatedTests", dependencies: ["Animated"], path: "Tests/AnimatedTests")
    ]
)
