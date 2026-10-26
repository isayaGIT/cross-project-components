// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProfileCard",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "ProfileCard", targets: ["ProfileCard"])],
    targets: [
        .target(name: "ProfileCard", swiftSettings: [.define("PROFILECARD_STANDALONE")]),
        .testTarget(name: "ProfileCardTests", dependencies: ["ProfileCard"])
    ]
)
