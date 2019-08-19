// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftDependencyGraph",
    products: [
        .executable(name: "swift-dependency-graph", targets: ["swift-dependency-graph"]),
        .library(name: "swift-dependency-graph-lib", targets: ["swift-dependency-graph-lib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client", .upToNextMajor(from: "1.0.0-alpha.1")),
        .package(url: "https://github.com/apple/swift-package-manager", .upToNextMinor(from: "0.4.0"))
    ],
    targets: [
        .target(name: "swift-dependency-graph", dependencies: ["swift-dependency-graph-lib"]),
        .target(name: "swift-dependency-graph-lib", dependencies: ["AsyncHTTPClient", "SwiftPM"]),
        .testTarget(name: "swift-dependency-graphTests", dependencies: ["swift-dependency-graph-lib"]),
    ]
)
