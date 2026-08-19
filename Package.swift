// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "fan-control",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "FanControlKit",
            targets: ["FanControlKit"]
        ),
        .executable(
            name: "fancontrol",
            targets: ["fancontrol"]
        )
    ],
    targets: [
        .target(
            name: "SMCBridge",
            path: "Sources/SMCBridge",
            publicHeadersPath: "include"
        ),
        .target(
            name: "FanControlKit",
            dependencies: ["SMCBridge"],
            path: "Sources/FanControlKit"
        ),
        .executableTarget(
            name: "fancontrol",
            dependencies: ["FanControlKit"],
            path: "Sources/fancontrol"
        ),
        .testTarget(
            name: "FanControlKitTests",
            dependencies: ["FanControlKit"],
            path: "Tests/FanControlKitTests"
        )
    ]
)
