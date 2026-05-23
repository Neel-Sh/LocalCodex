// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LocalCodex",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LocalCodex", targets: ["LocalCodex"])
    ],
    targets: [
        .executableTarget(name: "LocalCodex")
    ]
)
