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
        .package(url: "https://github.com/swift-server/async-http-client", .upToNextMajor(from: "1.0.0-alpha.1")),
        .package(url: "https://github.com/apple/swift-package-manager", .branch("swift-5.1-DEVELOPMENT-SNAPSHOT-2020-01-23-a")),
        .package(url: "https://github.com/kylef/commander", .upToNextMajor(from:"0.9.1"))
    ],
    targets: [
        .target(name: "swift-dependency-graph", dependencies: ["swift-dependency-graph-lib", "Commander"]),
        .target(name: "swift-dependency-graph-lib", dependencies: ["AsyncHTTPClient", "SwiftPM-auto"]),
        .testTarget(name: "swift-dependency-graphTests", dependencies: ["swift-dependency-graph-lib"]),
    ]
)
