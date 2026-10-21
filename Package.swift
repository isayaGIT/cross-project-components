// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CrossProjectComponents",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CrossProjectComponents", targets: ["CrossProjectComponents"])
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", .upToNextMinor(from: "2.4.1"))
    ],
    targets: [
        .target(
            name: "CrossProjectComponents",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Components",
            exclude: ["TreeView/API.md", "TreeView/demo.gif", "FilmstripScrubber/demo.gif", "MessageComposer/demo.gif", "SwipeBack/demo.gif", "MarkdownPreview/README.md"]
        )
    ]
)
