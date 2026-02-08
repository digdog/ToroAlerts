// swift-tools-version: 6.2.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ToroAlerts",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        // Library product
        .library(
            name: "ToroAlerts",
            targets: ["ToroAlerts"]
        ),
        // CLI executable
        .executable(
            name: "toroalertsctl",
            targets: ["ToroAlertsCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // Core Library
        .target(
            name: "ToroAlerts",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("Foundation")
            ]
        ),
        // CLI executable
        .executableTarget(
            name: "ToroAlertsCLI",
            dependencies: [
                "ToroAlerts",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Tools/ToroAlertsCLI"
        ),
        // Test target
        .testTarget(
            name: "ToroAlertsTests",
            dependencies: ["ToroAlerts"]
        )
    ],
    swiftLanguageModes: [.v6]
)
