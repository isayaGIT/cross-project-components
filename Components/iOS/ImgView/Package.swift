// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ImgView",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "ImgView", targets: ["ImgView"])],
    dependencies: [
        .package(url: "https://github.com/kean/Nuke.git", from: "13.0.0")
    ],
    targets: [
        .target(name: "ImgView", dependencies: [.product(name: "Nuke", package: "Nuke"), .product(name: "NukeUI", package: "Nuke")], path: "Sources/ImgView"),
        .testTarget(name: "ImgViewTests", dependencies: ["ImgView"], path: "Tests/ImgViewTests")
    ]
)
