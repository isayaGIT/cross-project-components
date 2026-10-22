// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Avatar",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "Avatar", targets: ["Avatar"])
    ],
    targets: [
        .target(name: "Avatar")
    ]
)
