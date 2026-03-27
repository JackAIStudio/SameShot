// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StreamSafeArea",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "StreamSafeArea", targets: ["StreamSafeArea"])
    ],
    targets: [
        .executableTarget(
            name: "StreamSafeArea",
            path: "Sources/StreamSafeArea"
        )
    ]
)
