// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StickerKeyboard",
    platforms: [.iOS(.v17)],
    products: [.library(name: "StickerKeyboard", targets: ["StickerKeyboard"])],
    dependencies: [
        .package(path: "../../../.."),
        .package(url: "https://github.com/kean/Nuke.git", from: "13.0.0")
    ],
    targets: [
        .target(
            name: "StickerKeyboard",
            dependencies: [
                .product(name: "StickerData", package: "cross-project-components"),
                .product(name: "CrossProjectComponentsIOS", package: "cross-project-components"),
                .product(name: "NukeUI", package: "Nuke")
            ],
            path: ".",
            exclude: ["README.md", "Package.swift"],
            swiftSettings: [.define("STICKER_KEYBOARD_STANDALONE")]
        )
    ]
)
