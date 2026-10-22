// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CrossProjectComponents",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        // Keep the original product/module name for existing macOS consumers.
        .library(name: "CrossProjectComponents", targets: ["CrossProjectComponents"]),
        .library(name: "CrossProjectComponentsIOS", targets: ["CrossProjectComponentsIOS"])
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Nuke.git", from: "13.0.0")
    ],
    targets: [
        .target(
            name: "CrossProjectComponents",
            path: "Components/macOS",
            exclude: ["TreeView/API.md", "TreeView/demo.gif", "FilmstripScrubber/demo.gif"]
        ),
        .target(
            name: "CrossProjectComponentsIOS",
            dependencies: [.product(name: "Nuke", package: "Nuke"), .product(name: "NukeUI", package: "Nuke")],
            path: "Components/iOS",
            exclude: ["MessageComposer/README.md", "SwipeBack/README.md", "Avatar/Package.swift", "Avatar/README.md", "Avatar/build.sh", "Avatar/Examples", "InputBar/README.md", "ImgPolaroid/Package.swift", "ImgPolaroid/README.md", "ImgPolaroid/Examples", "ImgPolaroid/Tests", "ImgView/Package.swift", "ImgView/README.md", "ImgView/Examples", "ImgView/Tests", "MessageBubble/README.md", "Trivial/StickerKeyboard/README.md"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CrossProjectComponentsIOSTests",
            dependencies: ["CrossProjectComponentsIOS"],
            path: "Tests/CrossProjectComponentsIOSTests"
        )
    ]
)
