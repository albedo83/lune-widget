// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MoonRender",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MoonRenderCore"),
        .executableTarget(name: "moonrender", dependencies: ["MoonRenderCore"]),
        .testTarget(name: "MoonRenderCoreTests", dependencies: ["MoonRenderCore"]),
    ]
)
