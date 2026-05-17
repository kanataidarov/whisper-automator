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
    dependencies: [
        // 1.16+ uses `#Preview`, which needs Xcode preview macros and fails under plain `swift build`.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", "1.15.0"..<"1.16.0")
    ],
    targets: [
        .executableTarget(
            name: "WhisperAutomator",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ]
        )
    ]
)
