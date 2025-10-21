// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// MARK: - Binary vs Source Distribution
//
// This package supports both binary (precompiled XCFramework) and source distribution:
//
// Binary Distribution (faster builds, all features enabled):
//   - Product: "AsyncDisplayKit" (default)
//   - Includes: Video, MapKit, Photos, AssetsLibrary, IGListKit (all traits)
//   - Best for: Production apps, faster CI builds
//
// Source Distribution (customizable, slower builds):
//   - Product: "AsyncDisplayKitSource"
//   - Supports: Selective trait configuration via SPM traits
//   - Best for: Development, debugging, custom configurations
//
// Note: Binary targets are currently commented out until first release is published.
// Uncomment and update the URL/checksum after creating a GitHub release.

// AsyncDisplayKit dependencies
let igListKitDep: Target.Dependency = .product(
    name: "IGListKit",
    package: "IGListKit",
    condition: .when(traits: ["IGListKit"])
)
let igListDiffKitDep: Target.Dependency = .product(
    name: "IGListDiffKit",
    package: "IGListKit",
    condition: .when(traits: ["IGListKit"])
)

let package = Package(
    name: "Texture",
    platforms: [
        .iOS(.v14),
        .tvOS(.v14),
        .macCatalyst(.v13)
    ],
    products: [
        // Default product - uses source distribution
        // TODO: After first binary release, change to ["AsyncDisplayKitBinaryWrapper"] for faster builds
        .library(
            name: "AsyncDisplayKit",
            targets: ["AsyncDisplayKit"]
        ),

        // Source distribution - always available for development/debugging
        .library(
            name: "AsyncDisplayKitSource",
            targets: ["AsyncDisplayKit"]
        ),

        // Binary distribution - uncomment after first release
        // .library(
        //     name: "AsyncDisplayKitBinary",
        //     targets: ["AsyncDisplayKitBinaryWrapper"]
        // ),

        .library(
            name: "TextureIGListKitExtensions",
            targets: ["TextureIGListKitExtensions"]
        )
    ],
    traits: [
        // Optional traits
        .init(name: "IGListKit", description: "IGListKit integration for advanced collection view support")
    ],
    dependencies: [
        .package(url: "https://github.com/pinterest/PINRemoteImage.git", from: "3.0.4"),
        .package(url: "https://github.com/Instagram/IGListKit", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "AsyncDisplayKit",
            dependencies: [
                "PINRemoteImage",
                igListKitDep,
                igListDiffKitDep
            ],
            path: "spm/Sources/AsyncDisplayKit",
            publicHeadersPath: "include",
            cSettings: [
                // Always available features
                .define("AS_PIN_REMOTE_IMAGE", to: "1"),

                // Disable old TextNode by default for SPM
                .define("AS_ENABLE_TEXTNODE", to: "0"),

                // Trait-based conditional defines
                .define("AS_IG_LIST_KIT", to: "1", .when(traits: ["IGListKit"])),
                .define("AS_IG_LIST_DIFF_KIT", to: "1", .when(traits: ["IGListKit"])),

                // Disabled features
                .define("AS_USE_VIDEO", to: "0"),           // Not accessible from Swift via SPM
                .define("AS_USE_MAPKIT", to: "0"),          // Not accessible from Swift via SPM
                .define("AS_USE_PHOTOS", to: "0"),          // Partially accessible from Swift via SPM
                .define("AS_USE_ASSETS_LIBRARY", to: "0"),  // Deprecated iOS 9.0, use Photos framework

                // Always disabled for SPM
                .define("IG_LIST_COLLECTION_VIEW", to: "0"),

                // Header search paths
                .headerSearchPath("."),
                .headerSearchPath("include/AsyncDisplayKit"),  // For quoted-style imports
                .headerSearchPath("Base"),
                .headerSearchPath("Debug"),
                .headerSearchPath("Details"),
                .headerSearchPath("Details/Transactions"),
                .headerSearchPath("Layout"),
                .headerSearchPath("Private"),
                .headerSearchPath("Private/Layout"),
                .headerSearchPath("TextExperiment/Component"),
                .headerSearchPath("TextExperiment/String"),
                .headerSearchPath("TextExperiment/Utility"),
                .headerSearchPath("TextKit"),
                .headerSearchPath("tvOS")
            ],
            cxxSettings: [
                .headerSearchPath("."),
                .headerSearchPath("include/AsyncDisplayKit"),  // For quoted-style imports
                .headerSearchPath("Base"),
                .headerSearchPath("Debug"),
                .headerSearchPath("Details"),
                .headerSearchPath("Details/Transactions"),
                .headerSearchPath("Layout"),
                .headerSearchPath("Private"),
                .headerSearchPath("Private/Layout"),
                .headerSearchPath("TextExperiment/Component"),
                .headerSearchPath("TextExperiment/String"),
                .headerSearchPath("TextExperiment/Utility"),
                .headerSearchPath("TextKit"),
                .headerSearchPath("tvOS")
            ],
            linkerSettings: [
                .linkedLibrary("c++")
                // Note: Video/MapKit/Photos frameworks not linked by default
                // These features are not accessible from Swift via SPM due to conditional compilation
                // Use CocoaPods or Carthage if you need these features, or use Objective-C code
            ]
        ),
        .target(
            name: "TextureIGListKitExtensions",
            dependencies: [
                "AsyncDisplayKit",
                igListKitDep
            ],
            path: "Sources/TextureIGListKitExtensions",
            swiftSettings: [
                .enableExperimentalFeature("AccessLevelOnImport"),
                // Use Swift 5 mode because this is a wrapper around Objective-C code
                // that lacks Swift Concurrency annotations. When AsyncDisplayKit adds
                // proper @MainActor annotations, we can migrate to Swift 6 mode.
                .swiftLanguageMode(.v5)
            ]
        ),

        // MARK: - Binary Distribution Targets (Commented until first release)
        //
        // Instructions to enable binary distribution:
        // 1. Run: ./scripts/build_xcframework.sh
        // 2. Create GitHub release and upload Texture.xcframework.zip
        // 3. Uncomment the targets below
        // 4. Update URL to: https://github.com/TextureGroup/Texture/releases/download/<version>/Texture.xcframework.zip
        // 5. Update checksum with value from build script output

        // Binary target - precompiled XCFramework with all features enabled
        // .binaryTarget(
        //     name: "AsyncDisplayKitBinary",
        //     url: "https://github.com/TextureGroup/Texture/releases/download/<VERSION>/Texture.xcframework.zip",
        //     checksum: "<CHECKSUM_FROM_BUILD_SCRIPT>"
        // ),

        // Wrapper target - links binary with SPM dependencies
        // This ensures dependencies (PINRemoteImage, IGListKit) are properly resolved
        // .target(
        //     name: "AsyncDisplayKitBinaryWrapper",
        //     dependencies: [
        //         "AsyncDisplayKitBinary",
        //         "PINRemoteImage",
        //         .product(name: "IGListKit", package: "IGListKit"),
        //         .product(name: "IGListDiffKit", package: "IGListKit")
        //     ],
        //     path: "spm/BinaryWrapper",
        //     linkerSettings: [
        //         .linkedFramework("AVFoundation"),
        //         .linkedFramework("CoreMedia"),
        //         .linkedFramework("CoreLocation"),
        //         .linkedFramework("MapKit"),
        //         .linkedFramework("Photos"),
        //         .linkedFramework("AssetsLibrary", .when(platforms: [.iOS])),
        //         .linkedLibrary("c++")
        //     ]
        // )
    ],
    cLanguageStandard: .c11,
    cxxLanguageStandard: .cxx20
)
