// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftDependencyGraph",
    platforms: [.macOS(.v10_13)],
    products: [
        .executable(name: "swift-dependency-graph", targets: ["swift-dependency-graph"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-package-manager", .branch("swift-5.1.5-RELEASE")),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.0.1")
    ],
    targets: [
        .target(name: "swift-dependency-graph", dependencies: ["swift-dependency-graph-lib", "ArgumentParser"]),
        .target(name: "swift-dependency-graph-lib", dependencies: ["AsyncHTTPClient", "SwiftPM-auto"]),
        .testTarget(name: "swift-dependency-graphTests", dependencies: ["swift-dependency-graph-lib"]),
    ]
)
