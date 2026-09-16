// swift-tools-version: 6.0
import PackageDescription
import Foundation

let isLocalSDK = FileManager.default.fileExists(atPath: "../droppykit/Package.swift")
let sdkPackageName = isLocalSDK ? "DroppyKit" : "droppykit"

let package = Package(
    name: "Battery",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Battery", type: .dynamic, targets: ["Battery"])
    ],
    dependencies: [
        isLocalSDK
            ? .package(path: "../droppykit")
            : .package(url: "https://gitlab.com/droppyformac1/droppykit.git", from: "1.6.0")
    ],
    targets: [
        .target(
            name: "Battery",
            dependencies: [.product(name: "DroppyKit", package: sdkPackageName)],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "BatteryHarness",
            dependencies: [
                "Battery",
                .product(name: "DroppyKitHarness", package: sdkPackageName)
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
