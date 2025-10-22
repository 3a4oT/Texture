// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UICoreKit",
    platforms: [
        .iOS(.v14),
        .macCatalyst(.v13)
    ],
    products: [
        .library(
            name: "UICoreKit",
            targets: ["UICoreKit"]
        )
    ],
    dependencies: [
        // 1. Added Texture package
        .package(
            path: "../../../../",
            // 2. IMPORTANT!! SET trait `IGListKit`
            traits: [
                .init(name: "IGListKit")
            ]
        )
    ],
    targets: [
        .target(
            name: "UICoreKit",
            dependencies: [
                .product(name: "AsyncDisplayKit", package: "Texture"),
                .product(name: "TextureIGListKitExtensions", package: "Texture")
            ],
            swiftSettings: [
                .enableExperimentalFeature("AccessLevelOnImport")
            ]
        ),
        .testTarget(
            name: "UICoreKitTests",
            dependencies: ["UICoreKit"]
        )
    ]
    )
