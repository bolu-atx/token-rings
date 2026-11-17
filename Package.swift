// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TokenRings",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TokenRings", targets: ["TokenRings"]),
        .library(name: "TokenRingsCore", targets: ["TokenRingsCore"])
    ],
    targets: [
        .target(name: "TokenRingsCore"),
        .executableTarget(name: "TokenRings", dependencies: ["TokenRingsCore"]),
        .testTarget(name: "TokenRingsCoreTests", dependencies: ["TokenRingsCore"])
    ]
)
