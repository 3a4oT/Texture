# Binary Distribution Guide

This document explains how to use and maintain Texture's binary distribution via XCFramework.

## Table of Contents

- [Overview](#overview)
- [Binary vs Source Distribution](#binary-vs-source-distribution)
- [Feature Comparison](#feature-comparison)
- [IGListKit Integration Differences](#iglistkit-integration-differences)
- [For Users](#for-users)
- [Runtime Configuration](#runtime-configuration)
- [For Maintainers](#for-maintainers)
- [FAQ](#faq)

---

## Overview

Texture provides two distribution methods via Swift Package Manager:

### Binary Distribution (XCFramework)
- **Pros:** Significantly faster build times (no compilation needed)
- **Cons:** Fixed feature set, Objective-C IGListKit API only
- **Best for:** Production apps, CI builds, Objective-C codebases
- **Size:** ~15-18 MB
- **Build time savings:** 2-5 minutes per clean build

### Source Distribution
- **Pros:** Customizable via traits, modern Swift IGListKit API
- **Cons:** Slower builds (full compilation required)
- **Best for:** Development, Swift codebases, apps needing ASMapNode
- **Size:** ~5 MB source
- **Build time:** 2-5 minutes per clean build

---

## Binary vs Source Distribution

### Quick Comparison Table

| Feature | Binary Distribution | Source Distribution |
|---------|-------------------|---------------------|
| **Build Speed** | Instant (pre-compiled) | 2-5 minutes |
| **Core Nodes** | All included | All included |
| **Video (ASVideoNode)** | Included | Included (default trait) |
| **Photos Framework** | Included | Included (default trait) |
| **IGListKit Integration** | Objective-C API only | **Swift API (modern)** |
| **MapKit (ASMapNode)** | **Not included** | Optional trait |
| **AssetsLibrary** | **Not included** | Optional trait (deprecated) |
| **Old TextNode** | **Not included** | Available |
| **TextNode2** | Included (default) | Included (default) |
| **Language** | Objective-C/C++ | Objective-C/C++ + Swift |

---

## Feature Comparison

### What's Included in Binary Distribution

The binary is optimized for iOS 14+ with the most commonly used features:

#### Included (Ready to Use)

**Core Nodes:**
- ASDisplayNode, ASCellNode, ASScrollNode
- ASImageNode, ASNetworkImageNode, ASMultiplexImageNode
- ASTextNode2 (modern, performant text rendering)
- ASButtonNode, ASControlNode
- ASVideoNode, ASVideoPlayerNode (video support)
- ASCollectionNode, ASTableNode, ASPagerNode
- All layout specs (ASStackLayoutSpec, ASInsetLayoutSpec, etc.)

**Framework Integration:**
- Photos framework support (PHAsset, PHImageManager)
- PINRemoteImage integration (image downloading/caching)
- **IGListKit integration (Objective-C API only)**

**Why These Are Included:**
- Used by 90%+ of Texture apps
- Core functionality most apps need
- Video and photos are very common

#### Not Included (Use Source Distribution)

**ASMapNode (MapKit Integration):**
- Only ~10% of apps display maps
- Adds 100-200KB to binary
- Requires linking MapKit.framework + CoreLocation.framework
- **Migration path:** Use source distribution with MapKit trait

**AssetsLibrary:**
- Deprecated in iOS 9.0 (2015)
- Fully replaced by Photos framework (iOS 8+)
- Binary targets iOS 14+ (2020)
- **Migration path:** Use Photos framework APIs instead

**Old TextNode:**
- Legacy text rendering engine
- Slower than TextNode2
- Less features than TextNode2
- **Migration path:** Use TextNode2 (default in binary)

**TextureIGListKitExtensions (Swift API):**
- Modern Swift API for IGListKit
- Source distribution only
- **Migration path:** See IGListKit Integration Differences section

---

## IGListKit Integration Differences

### CRITICAL: Binary vs Source Use Different APIs

This is the most important difference between binary and source distribution.

### Binary Distribution: Objective-C API Only

**What you get:**
- `IGListAdapter+AsyncDisplayKit` category (Objective-C)
- Method: `-[IGListAdapter setASDKCollectionNode:]`
- Implementation: `ASIGListAdapterBasedDataSource` (Objective-C)
- Based on original Facebook/Pinterest Objective-C code

**Usage (Objective-C):**
```objc
@import IGListKit;
@import AsyncDisplayKit;

IGListAdapter *adapter = [[IGListAdapter alloc] initWithUpdater:...
                                                 viewController:...];
ASCollectionNode *node = [[ASCollectionNode alloc] init];

// Binary distribution uses Objective-C API
[adapter setASDKCollectionNode:node];
```

**Usage (Swift with binary):**
```swift
import IGListKit
import AsyncDisplayKit

let adapter = ListAdapter(updater: ..., viewController: ...)
let node = ASCollectionNode()

// Must use Objective-C selector from Swift
adapter.setASDKCollectionNode(node)
```

**Limitations:**
- Objective-C naming convention (ASDK prefix)
- No Swift-specific features
- No modern Swift concurrency annotations
- Same as CocoaPods/Carthage builds

### Source Distribution: Modern Swift API

**What you get:**
- `TextureIGListKitExtensions` module (pure Swift)
- Method: `ListAdapter.setCollectionNode(_:)` (Swift extension)
- Implementation: Swift bridge to Objective-C internals
- Modern, idiomatic Swift API

**Usage (Swift with source):**
```swift
import TextureIGListKitExtensions
// This single import provides:
//   - AsyncDisplayKit APIs
//   - IGListKit APIs
//   - IGListDiffKit APIs
//   - Swift extension method

let adapter = ListAdapter(updater: ..., viewController: ...)
let node = ASCollectionNode()

// Source distribution uses Swift API
adapter.setCollectionNode(node)
```

**Advantages:**
- Idiomatic Swift naming (no ASDK prefix)
- Single import for all modules
- Future Swift concurrency support
- Better type safety

**Usage (Objective-C with source):**
```objc
// TextureIGListKitExtensions is Swift-only
// Use the original Objective-C API:
@import IGListKit;
@import AsyncDisplayKit;

[adapter setASDKCollectionNode:node];
```

### Why This Difference Exists

**Technical Reason:**

Binary XCFrameworks are pre-compiled and cannot include:
- Swift-only modules (TextureIGListKitExtensions)
- SPM trait-conditional Swift code
- Swift evolution features

Source distribution can:
- Compile Swift code at build time
- Use SPM traits to conditionally include Swift modules
- Provide modern Swift APIs

**Design Decision:**

Binary includes the **core Objective-C implementation** that works everywhere:
- CocoaPods users: same API
- Carthage users: same API
- Binary SPM users: same API

Source distribution adds **optional Swift sugar** on top:
- Source SPM users: modern Swift API
- But Objective-C API still available

### Migration Guide: Binary → Source for Swift API

If you want the modern Swift API:

1. **Change Package.swift:**
```swift
// From:
.product(name: "AsyncDisplayKitBinary", package: "Texture")

// To:
.product(name: "AsyncDisplayKitSource", package: "Texture", traits: [.init(name: "IGListKit")])
.product(name: "TextureIGListKitExtensions", package: "Texture")
```

2. **Update imports:**
```swift
// From:
import IGListKit
import AsyncDisplayKit

// To:
import TextureIGListKitExtensions  // Includes everything
```

3. **Update API calls:**
```swift
// From:
adapter.setASDKCollectionNode(node)

// To:
adapter.setCollectionNode(node)
```

### Comparison Table

| Aspect | Binary (Objective-C API) | Source (Swift API) |
|--------|-------------------------|-------------------|
| **API Method** | `setASDKCollectionNode:` | `setCollectionNode(_:)` |
| **Language** | Objective-C | Swift |
| **Module** | `IGListAdapter+AsyncDisplayKit` | `TextureIGListKitExtensions` |
| **Import** | `@import IGListKit` + `@import AsyncDisplayKit` | `import TextureIGListKitExtensions` |
| **Naming** | ASDK prefix | Swift naming conventions |
| **CocoaPods Compatible** | Yes (same API) | No (SPM only) |
| **Carthage Compatible** | Yes (same API) | No (SPM only) |
| **Swift Concurrency** | No | Future support |
| **Type Safety** | Objective-C | Swift |

### Which Should You Use?

**Use Binary Distribution (Objective-C API) if:**
- You have an Objective-C codebase
- You're migrating from CocoaPods/Carthage
- You want fastest builds
- You don't need ASMapNode

**Use Source Distribution (Swift API) if:**
- You have a Swift codebase
- You want modern Swift APIs
- You need ASMapNode
- You prefer idiomatic Swift naming

---

## For Users

### Using Binary Distribution

```swift
dependencies: [
    .package(url: "https://github.com/TextureGroup/Texture", from: "3.2.1")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "AsyncDisplayKitBinary", package: "Texture")
        ],
        linkerSettings: [
            .linkedLibrary("c++"),
            .linkedFramework("AVFoundation"),
            .linkedFramework("CoreMedia"),
            .linkedFramework("Photos")
        ]
    )
]
```

**IGListKit usage with binary:**
```swift
import IGListKit
import AsyncDisplayKit

// Use Objective-C API
adapter.setASDKCollectionNode(node)
```

### Using Source Distribution with Swift API

```swift
dependencies: [
    .package(
        url: "https://github.com/TextureGroup/Texture",
        from: "3.2.1",
        traits: [.init(name: "IGListKit")]  // Enable IGListKit trait
    )
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "AsyncDisplayKit", package: "Texture"),
            .product(name: "TextureIGListKitExtensions", package: "Texture")
        ]
    )
]
```

**IGListKit usage with source:**
```swift
import TextureIGListKitExtensions

// Use Swift API
adapter.setCollectionNode(node)
```

---

## Runtime Configuration

### Required Framework Linking for Binary

```swift
linkerSettings: [
    // ALWAYS REQUIRED
    .linkedLibrary("c++"),

    // REQUIRED for binary
    .linkedFramework("AVFoundation"),
    .linkedFramework("CoreMedia"),
    .linkedFramework("Photos")
]
```

### NOT Required for Binary

```swift
// DON'T ADD for binary:
// .linkedFramework("MapKit")         // ASMapNode not in binary
// .linkedFramework("CoreLocation")   // ASMapNode not in binary
// .linkedFramework("AssetsLibrary")  // Deprecated, not in binary
```

---

## For Maintainers

### Building XCFramework

```bash
./scripts/build_xcframework.sh
```

**Build configuration:**
- `AS_ENABLE_TEXTNODE=0` (use TextNode2)
- `AS_USE_ASSETS_LIBRARY=0` (deprecated)
- `AS_USE_MAPKIT=0` (niche use case)
- `AS_USE_PHOTOS=1` (common)
- `AS_USE_VIDEO=1` (common)
- `AS_IG_LIST_KIT=1` (Objective-C implementation only)

**Note:** Swift module `TextureIGListKitExtensions` is NOT included in binary.

---

## FAQ

### Why is IGListKit API different in binary vs source?

Binary XCFrameworks cannot include Swift-only modules. Binary includes the core Objective-C implementation (`setASDKCollectionNode:`), while source distribution adds optional Swift sugar (`setCollectionNode(_:)`).

Both APIs use the same underlying implementation - only the Swift wrapper is different.

### Can I use the Swift API with binary distribution?

No. The Swift API (`TextureIGListKitExtensions`) requires source compilation. Use source distribution if you want modern Swift APIs.

### Will my CocoaPods/Carthage code work with binary?

Yes! Binary uses the same Objective-C API as CocoaPods/Carthage (`setASDKCollectionNode:`). It's a drop-in replacement.

### Why is ASMapNode not in the binary?

Only ~10% of apps use maps. Removing it:
- Reduces binary by 100-200KB
- Removes MapKit.framework dependency
- Serves 90% of use cases

Apps needing ASMapNode can use source distribution.

### What about AssetsLibrary?

Deprecated in iOS 9.0 (2015). Binary targets iOS 14+ (2020). Use Photos framework instead.

### Does Library Evolution work?

Yes! Binary built with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`:
- Works across Swift versions
- No rebuild for new Xcode
- Binary compatible

### Can I use both binary and source?

No, SPM doesn't allow this. Choose one per project.

---

## Additional Resources

- [TextureIGListKitExtensions README](../Sources/TextureIGListKitExtensions/README.md) - Swift API details
- [Swift Package Manager Documentation](https://swift.org/package-manager/)
- [XCFramework Documentation](https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle)
- [Photos Framework Migration Guide](https://developer.apple.com/documentation/photokit)
