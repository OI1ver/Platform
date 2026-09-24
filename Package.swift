// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Platform",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Platform", targets: ["PlatformApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.10.0")
    ],
    targets: [
        .executableTarget(
            name: "PlatformApp",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "PlatformAppTests",
            dependencies: ["PlatformApp"]
        )
    ]
)
