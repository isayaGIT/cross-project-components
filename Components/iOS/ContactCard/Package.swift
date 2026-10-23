// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ContactCard",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "ContactCard", targets: ["ContactCard"])],
    targets: [
        .target(name: "ContactCard"),
        .testTarget(name: "ContactCardTests", dependencies: ["ContactCard"])
    ]
)
