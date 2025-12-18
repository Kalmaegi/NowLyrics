// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NowLyrics",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "NowLyrics",
            targets: ["NowLyrics"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "NowLyrics",
            dependencies: [
                "SnapKit",
            ],
            path: "NowLyrics/Sources",
            resources: [
                .process("../Assets.xcassets"),
            ]
        ),
    ]
)