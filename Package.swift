// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Battery",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Battery", type: .dynamic, targets: ["Battery"])
    ],
    dependencies: [
        .package(url: "https://gitlab.com/droppyformac1/droppykit.git", from: "1.6.0")
    ],
    targets: [
        .target(
            name: "Battery",
            dependencies: [.product(name: "DroppyKit", package: "droppykit")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "BatteryHarness",
            dependencies: [
                "Battery",
                .product(name: "DroppyKitHarness", package: "droppykit")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
