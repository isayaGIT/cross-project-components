// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProfileCard",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "ProfileCard", targets: ["ProfileCard"])],
    targets: [
        .target(name: "ProfileCard"),
        .testTarget(name: "ProfileCardTests", dependencies: ["ProfileCard"])
    ]
)
