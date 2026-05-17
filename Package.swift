// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Idol Follower",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/warrenm/GLTFKit2", from: "0.5.0")
    ],
    targets: [
        .executableTarget(
            name: "IdolFollower",
            dependencies: [
                .product(name: "GLTFKit2", package: "GLTFKit2")
            ],
            path: "Sources"
        )
    ]
)
