// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "CrossProjectComponents", platforms: [.macOS(.v13)], products: [.library(name: "CrossProjectComponents", targets: ["CrossProjectComponents"])], targets: [.target(name: "CrossProjectComponents"), .testTarget(name: "CrossProjectComponentsTests", dependencies: ["CrossProjectComponents"])])
