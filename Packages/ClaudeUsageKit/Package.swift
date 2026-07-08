// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ClaudeUsageKit",
            targets: ["ClaudeUsageKit"]
        )
    ],
    targets: [
        .target(
            name: "ClaudeUsageKit"
        ),
        .testTarget(
            name: "ClaudeUsageKitTests",
            dependencies: ["ClaudeUsageKit"]
        )
    ]
)
