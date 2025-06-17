// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftABNF",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ABNFLib",
            targets: ["ABNFLib"]),
        .executable(
            name: "abnf",
            targets: ["abnf"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ABNFLib"),
        .executableTarget(
            name: "abnf",
            dependencies: [
                "ABNFLib",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .testTarget(
            name: "ABNFLibTests",
            dependencies: ["ABNFLib"],
            resources: [
                .copy("postal_address.abnf"),
            ]
        ),
    ]
)
