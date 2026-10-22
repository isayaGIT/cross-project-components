// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LineDashed",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "LineDashed", targets: ["LineDashed"])],
    targets: [
        .target(name: "LineDashed"),
        .testTarget(name: "LineDashedTests", dependencies: ["LineDashed"])
    ]
)
