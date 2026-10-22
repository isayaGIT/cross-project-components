// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CrossProjectComponents",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "CrossProjectComponents", targets: ["CrossProjectComponents"]),
        .library(name: "CrossProjectComponentsIOS", targets: ["CrossProjectComponentsIOS"]),
        .library(name: "StickerData", targets: ["StickerData"]),
        .library(name: "ImgData", targets: ["ImgData"]),
        .library(name: "BackgroundData", targets: ["BackgroundData"])
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Nuke.git", from: "13.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", .upToNextMinor(from: "2.4.1")),
        .package(path: "Shapes/LineDashed"),
        .package(path: "Textures/LiquidGlass")
    ],
    targets: [
        .target(
            name: "CrossProjectComponents",
            dependencies: [.product(name: "MarkdownUI", package: "swift-markdown-ui"), .product(name: "LineDashed", package: "LineDashed")],
            path: "Components/macOS",
            exclude: ["TreeView/API.md", "TreeView/demo.gif", "FilmstripScrubber/demo.gif"]
        ),
        .target(
            name: "CrossProjectComponentsIOS",
            dependencies: [.product(name: "Nuke", package: "Nuke"), .product(name: "NukeUI", package: "Nuke"), .product(name: "LineDashed", package: "LineDashed"), .product(name: "LiquidGlassKit", package: "LiquidGlass", condition: .when(platforms: [.iOS])), "StickerData", "ImgData", "BackgroundData"],
            path: "Components/iOS",
            exclude: ["Animated", "MessageComposer/README.md", "SwipeBack/README.md", "Avatar/Package.swift", "Avatar/README.md", "Avatar/build.sh", "Avatar/Examples", "InputBar/README.md", "ImgPolaroid/Package.swift", "ImgPolaroid/README.md", "ImgPolaroid/Examples", "ImgPolaroid/Tests", "ImgView/Package.swift", "ImgView/README.md", "ImgView/Examples", "ImgView/Tests", "MessageBubble/README.md", "VoiceMessage/README.md", "MomentSingleMoment/README.md", "MomentSingleMoment/Examples", "Trivial/StickerKeyboard/README.md", "Trivial/StickerKeyboard/Package.swift"],
            resources: [.process("Resources")]
        ),
        .target(name: "StickerData", path: "Class/Sticker", exclude: ["README.md"]),
        .target(name: "ImgData", path: "Class/Img", exclude: ["README.md"]),
        .target(name: "BackgroundData", path: "Class/Background"),
        .testTarget(name: "ImgDataTests", dependencies: ["ImgData"], path: "Tests/ImgDataTests"),
        .testTarget(name: "StickerDataTests", dependencies: ["StickerData"], path: "Tests/StickerDataTests"),
        .testTarget(name: "CrossProjectComponentsIOSTests", dependencies: ["CrossProjectComponentsIOS"], path: "Tests/CrossProjectComponentsIOSTests")
    ]
)
