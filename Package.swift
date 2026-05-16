// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WhisperAutomator",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "WhisperAutomator",
            targets: ["WhisperAutomator"]
        )
    ],
    targets: [
        .executableTarget(
            name: "WhisperAutomator"
        )
    ]
)
