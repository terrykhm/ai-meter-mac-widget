// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AIMeterKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AIMeterKit",
            targets: ["AIMeterKit"]
        )
    ],
    targets: [
        .target(
            name: "AIMeterKit"
        ),
        .testTarget(
            name: "AIMeterKitTests",
            dependencies: ["AIMeterKit"]
        )
    ]
)
