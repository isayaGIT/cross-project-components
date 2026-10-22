// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ImgPolaroid",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "ImgPolaroid", targets: ["ImgPolaroid"])],
    targets: [
        .target(name: "ImgPolaroid", path: "Sources/ImgPolaroid"),
        .testTarget(name: "ImgPolaroidTests", dependencies: ["ImgPolaroid"], path: "Tests/ImgPolaroidTests")
    ]
)
