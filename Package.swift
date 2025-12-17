// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftDependencyGraph",
    platforms: [.macOS("10.15.4")],
    products: [
        .executable(name: "swift-dependency-graph", targets: ["swift-dependency-graph"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.22.0"),
        .package(name: "SwiftPM", url: "https://github.com/apple/swift-package-manager.git", branch: "swift-5.8-RELEASE"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "swift-dependency-graph", dependencies: [
            "swift-dependency-graph-lib",
            .product(name: "ArgumentParser", package: "swift-argument-parser")
        ]),
        .target(name: "swift-dependency-graph-lib", dependencies: [
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
            .product(name: "SwiftPM-auto", package: "SwiftPM")
        ]),
        .testTarget(name: "swift-dependency-graphTests",
                    dependencies: ["swift-dependency-graph-lib"],
                    resources: [.process("packages.json")]),
    ]
)
