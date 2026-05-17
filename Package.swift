// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Idol Follower",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "IdolFollower",
            path: "Sources"
        )
    ]
)
