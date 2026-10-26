// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LuneKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LuneKit", targets: ["LuneKit"]),
    ],
    targets: [
        .target(name: "LuneKit"),
        .testTarget(name: "LuneKitTests", dependencies: ["LuneKit"]),
    ],
    swiftLanguageModes: [.v6]
)
