// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-dependency-graph",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .executable(name: "swift-dependency-graph", targets: ["swift-dependency-graph"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/swift-server/async-http-client", .upToNextMajor(from: "1.0.0-alpha.1"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(name: "swift-dependency-graph", dependencies: ["AsyncHTTPClient"]),
        .testTarget(name: "swift-dependency-graphTests", dependencies: ["swift-dependency-graph"]),
    ]
)
