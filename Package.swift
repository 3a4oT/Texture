// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

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
        .library(
            name: "AsyncDisplayKit",
            targets: ["AsyncDisplayKit"]
        ),
        .library(
            name: "TextureIGListKitExtensions",
            targets: ["TextureIGListKitExtensions"]
        )
    ],
    traits: [
        // Default traits - enabled by default for backwards compatibility with CocoaPods
        .default(enabledTraits: [
            "Video",
            "MapKit",
            "Photos",
            "AssetsLibrary"
        ]),

        // Define all traits with descriptions
        .init(name: "Video", description: "Video node support with AVFoundation and CoreMedia"),
        .init(name: "MapKit", description: "MapKit integration for map nodes"),
        .init(name: "Photos", description: "Photos framework support"),
        .init(name: "AssetsLibrary", description: "Legacy AssetsLibrary support (iOS only)"),

        // Optional traits - must be explicitly enabled
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
                // PINRemoteImage is always available
                .define("AS_PIN_REMOTE_IMAGE", to: "1"),

                // Disable old TextNode by default for SPM
                .define("AS_ENABLE_TEXTNODE", to: "0"),

                // Trait-based conditional defines
                .define("AS_USE_VIDEO", to: "1", .when(traits: ["Video"])),
                .define("AS_USE_MAPKIT", to: "1", .when(traits: ["MapKit"])),
                .define("AS_USE_PHOTOS", to: "1", .when(traits: ["Photos"])),
                .define("AS_USE_ASSETS_LIBRARY", to: "1", .when(traits: ["AssetsLibrary"])),
                .define("AS_IG_LIST_KIT", to: "1", .when(traits: ["IGListKit"])),
                .define("AS_IG_LIST_DIFF_KIT", to: "1", .when(traits: ["IGListKit"])),

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
                .linkedFramework("AVFoundation", .when(traits: ["Video"])),
                .linkedFramework("CoreMedia", .when(traits: ["Video"])),
                .linkedFramework("CoreLocation", .when(traits: ["MapKit"])),
                .linkedFramework("MapKit", .when(traits: ["MapKit"])),
                .linkedFramework("Photos", .when(traits: ["Photos"])),
                .linkedFramework("AssetsLibrary", .when(platforms: [.iOS], traits: ["AssetsLibrary"])),
                .linkedLibrary("c++")
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
        )
    ],
    cLanguageStandard: .c11,
    cxxLanguageStandard: .cxx20
)
