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
        .library(name: "CrossProjectComponentsIOS", targets: ["CrossProjectComponentsIOS"]),
        .library(name: "StickerData", targets: ["StickerData"]),
        .library(name: "ImgData", targets: ["ImgData"])
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
            dependencies: [.product(name: "Nuke", package: "Nuke"), .product(name: "NukeUI", package: "Nuke"), "StickerData", "ImgData"],
            path: "Components/iOS",
            exclude: ["MessageComposer/README.md", "SwipeBack/README.md", "Avatar/Package.swift", "Avatar/README.md", "Avatar/build.sh", "Avatar/Examples", "InputBar/README.md", "ImgPolaroid/Package.swift", "ImgPolaroid/README.md", "ImgPolaroid/Examples", "ImgPolaroid/Tests", "ImgView/Package.swift", "ImgView/README.md", "ImgView/Examples", "ImgView/Tests", "MessageBubble/README.md", "MomentSingleMoment/Examples", "Trivial/StickerKeyboard/README.md", "Trivial/StickerKeyboard/Package.swift"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "StickerData",
            path: "Class/Sticker",
            exclude: ["README.md"]
        ),
        .target(
            name: "ImgData",
            path: "Class/Img",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "ImgDataTests",
            dependencies: ["ImgData"],
            path: "Tests/ImgDataTests"
        ),
        .testTarget(
            name: "StickerDataTests",
            dependencies: ["StickerData"],
            path: "Tests/StickerDataTests"
        ),
        .testTarget(
            name: "CrossProjectComponentsIOSTests",
            dependencies: ["CrossProjectComponentsIOS"],
            path: "Tests/CrossProjectComponentsIOSTests"
        )
    ]
)
