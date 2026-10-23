// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InteractiveAssets",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "InteractiveAssets", targets: ["InteractiveAssets"])
    ],
    targets: [
        .target(name: "InteractiveAssets"),
        .testTarget(name: "InteractiveAssetsTests", dependencies: ["InteractiveAssets"])
    ]
)
