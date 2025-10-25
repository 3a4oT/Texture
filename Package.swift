// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// MARK: - Binary vs Source Distribution
//
// This package supports both binary (precompiled XCFramework) and source distribution:
//
// Binary Distribution:
//   - Product: "AsyncDisplayKitBinary"
//   - Includes: Core AsyncDisplayKit, PINRemoteImage, TextNode2, IGListKit (Objective-C API)
//   - IGListKit: ✅ Native Objective-C API (adapter.setASDKCollectionNode)
//   - Best for: Production apps, faster builds (pre-compiled)
//
// Source Distribution:
//   - Product: "AsyncDisplayKit" (default)
//   - Includes: Core AsyncDisplayKit, PINRemoteImage, TextNode2
//   - IGListKit: ❌ Objective-C API not available (use TextureIGListKitExtensions instead)
//   - Best for: Development, debugging, custom configurations
//
// ⚠️ IGListKit API Differences:
//
// SPM Source:         adapter.setCollectionNode(node)     // Swift API (TextureIGListKitExtensions)
// SPM Binary/Carthage: adapter.setASDKCollectionNode(node) // Objective-C API
//
// ⚠️ Method names differ - not drop-in replacements!
// See Sources/TextureIGListKitExtensions/README.md for API mapping.
//
// ⚠️ Other SPM Limitations:
// Video/MapKit/Photos features not available from Swift in Source distribution.
// Available in Binary distribution and Carthage (pre-compiled frameworks).

// AsyncDisplayKit dependencies - IGListKit is always required

let package = Package(
    name: "Texture",
    platforms: [
        .iOS(.v14),
        .tvOS(.v14),
        .macCatalyst(.v13)
    ],
    products: [
        // Default product - source distribution
        .library(
            name: "AsyncDisplayKit",
            targets: ["AsyncDisplayKit"]
        ),

        // Binary distribution - pre-compiled XCFramework
        .library(
            name: "AsyncDisplayKitBinary",
            targets: ["AsyncDisplayKitBinaryWrapper"]
        ),

        .library(
            name: "TextureIGListKitExtensions",
            targets: ["TextureIGListKitExtensions"]
        )
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
                .product(name: "IGListKit", package: "IGListKit"),
                .product(name: "IGListDiffKit", package: "IGListKit")
            ],
            path: "spm/Sources/AsyncDisplayKit",
            publicHeadersPath: "include",
            cSettings: [
                // Always available features
                .define("AS_PIN_REMOTE_IMAGE", to: "1"),
                
                // IGListKit: Disabled for SPM Source (use TextureIGListKitExtensions instead)
                // Enabled for Binary/Carthage builds (native Objective-C API)
                .define("AS_IG_LIST_KIT", to: "0"),
                .define("AS_IG_LIST_DIFF_KIT", to: "0"),

                // Disable old TextNode by default for SPM
                .define("AS_ENABLE_TEXTNODE", to: "0"),

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
                .product(name: "IGListKit", package: "IGListKit")
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

        // MARK: - Binary Distribution Targets
        //
        // Binary distribution provides pre-compiled XCFramework for faster build times.
        // Includes: Core AsyncDisplayKit, Photos framework, PINRemoteImage, IGListKit (Objective-C API)
        // See docs/BinaryDistribution.md for details

        // Binary target - precompiled XCFramework
        .binaryTarget(
            name: "AsyncDisplayKitBinary",
            url: "https://github.com/3a4oT/Texture/releases/download/4.0.3/Texture.xcframework.zip",
            checksum: "825dcee8198c36971cde668fe8b91affff1bac61986019cfdcdf2b99156e49b2"
        ),

        // Wrapper target - links binary with SPM dependencies
        // This ensures dependencies (PINRemoteImage, IGListKit) are properly resolved
        .target(
            name: "AsyncDisplayKitBinaryWrapper",
            dependencies: [
                "AsyncDisplayKitBinary",
                "PINRemoteImage",
                .product(name: "IGListKit", package: "IGListKit"),
                .product(name: "IGListDiffKit", package: "IGListKit")
            ],
            path: "spm/BinaryWrapper",
            linkerSettings: [
                .linkedFramework("Photos"),  // Required for ASMultiplexImageNode PHAsset support
                .linkedLibrary("c++")
                // Note: Video/MapKit features not included in binary
                // Use CocoaPods/Carthage if you need ASVideoNode or ASMapNode
            ]
        )
    ],
    cLanguageStandard: .c11,
    cxxLanguageStandard: .cxx20
)
