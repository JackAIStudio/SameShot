// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SameShot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SameShot", targets: ["SameShot"])
    ],
    targets: [
        .executableTarget(
            name: "SameShot",
            path: "Sources/SameShot"
        ),
        .testTarget(
            name: "SameShotTests",
            dependencies: ["SameShot"],
            path: "Tests/SameShotTests"
        )
    ]
)
