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
- **Cons:** Objective-C IGListKit API only (no Swift API)
- **Best for:** Production apps, CI builds, Objective-C codebases
- **Size:** ~15-18 MB
- **Build time savings:** 2-5 minutes per clean build

### Source Distribution
- **Pros:** Modern Swift IGListKit API available
- **Cons:** Slower builds (full compilation required)
- **Best for:** Development, Swift codebases needing Swift API
- **Size:** ~5 MB source
- **Build time:** 2-5 minutes per clean build

### ⚠️ Important SPM Limitation (Both Binary and Source)

Video (ASVideoNode), MapKit (ASMapNode), and Photos features are **NOT available** via Swift Package Manager due to technical limitations. These Objective-C classes are wrapped in conditional compilation directives (`#if AS_USE_VIDEO`) which prevents them from being exported in the Swift module interface.

**If you need these features:**
- Use CocoaPods or Carthage (original repository)
- Or use from Objective-C code (.m files)

---

## Binary vs Source Distribution

### Quick Comparison Table

| Feature | Binary Distribution | Source Distribution |
|---------|-------------------|---------------------|
| **Build Speed** | Instant (pre-compiled) | 2-5 minutes |
| **Core Nodes** | All included | All included |
| **Video (ASVideoNode)** | ❌ Not available (SPM limitation) | ❌ Not available (SPM limitation) |
| **Photos Framework** | ❌ Not available (SPM limitation) | ❌ Not available (SPM limitation) |
| **MapKit (ASMapNode)** | ❌ Not available (SPM limitation) | ❌ Not available (SPM limitation) |
| **IGListKit Integration** | ✅ Objective-C API only | ✅ **Swift API (modern)** |
| **AssetsLibrary** | ❌ Deprecated iOS 9.0 | ❌ Deprecated iOS 9.0 |
| **Old TextNode** | ❌ Not included | ❌ Not included |
| **TextNode2** | ✅ Included (default) | ✅ Included (default) |
| **PINRemoteImage** | ✅ Included | ✅ Included |
| **Language** | Objective-C/C++ | Objective-C/C++ + Swift |

**Note:** To use Video/MapKit/Photos features, use CocoaPods or Carthage from the original repository.

---

## Feature Comparison

### What's Included in Binary Distribution

The binary is optimized for iOS 14+ with core Texture functionality:

#### Included (Ready to Use)

**Core Nodes:**
- ASDisplayNode, ASCellNode, ASScrollNode
- ASImageNode, ASNetworkImageNode, ASMultiplexImageNode
- ASTextNode2 (modern, performant text rendering)
- ASButtonNode, ASControlNode
- ASCollectionNode, ASTableNode, ASPagerNode
- All layout specs (ASStackLayoutSpec, ASInsetLayoutSpec, etc.)

**Framework Integration:**
- PINRemoteImage integration (image downloading/caching)
- IGListKit integration (Objective-C API only)

**Why These Are Included:**
- Core functionality that works via SPM
- Used by most Texture apps
- Available from Swift code

#### Not Available (SPM Limitations - Both Binary and Source)

**ASVideoNode, ASVideoPlayerNode (Video Support):**
- ❌ Not accessible from Swift via SPM
- Wrapped in `#if AS_USE_VIDEO` preprocessor directive
- Classes not exported in Swift module interface
- **Migration path:** Use CocoaPods/Carthage, or Objective-C .m files

**ASMapNode (MapKit Integration):**
- ❌ Not accessible from Swift via SPM
- Wrapped in `#if AS_USE_MAPKIT` preprocessor directive
- Classes not exported in Swift module interface
- **Migration path:** Use CocoaPods/Carthage, or Objective-C .m files

**Photos Framework Integration:**
- ❌ Partially accessible from Swift via SPM
- Some helpers wrapped in `#if AS_USE_PHOTOS`
- **Migration path:** Use CocoaPods/Carthage, or Objective-C .m files

**AssetsLibrary:**
- ❌ Deprecated in iOS 9.0 (2015)
- ❌ Not available via SPM
- **Migration path:** Use Photos framework via CocoaPods/Carthage

**Old TextNode:**
- ❌ Legacy text rendering engine
- Removed in favor of TextNode2
- **Migration path:** Use TextNode2 (default)

**TextureIGListKitExtensions (Swift API):**
- ✅ Available in source distribution only
- Modern Swift API for IGListKit
- **Migration path:** Use source distribution with IGListKit trait

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
- You don't need Video/MapKit/Photos features

**Use Source Distribution (Swift API) if:**
- You have a Swift codebase
- You want modern Swift APIs for IGListKit
- You prefer idiomatic Swift naming
- Build time is acceptable (2-5 minutes)

**Use CocoaPods or Carthage (original repository) if:**
- You need Video (ASVideoNode) features
- You need MapKit (ASMapNode) features
- You need Photos framework integration
- You're okay with longer build times

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
            .linkedLibrary("c++")
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
    .linkedLibrary("c++")
]
```

### NOT Required for Binary (SPM Limitations)

```swift
// DON'T ADD for binary or source - these features are not available via SPM:
// .linkedFramework("AVFoundation")   // Video not accessible from Swift
// .linkedFramework("CoreMedia")      // Video not accessible from Swift
// .linkedFramework("Photos")         // Photos not accessible from Swift
// .linkedFramework("MapKit")         // ASMapNode not accessible from Swift
// .linkedFramework("CoreLocation")   // ASMapNode not accessible from Swift
// .linkedFramework("AssetsLibrary")  // Deprecated iOS 9.0

// To use these features, use CocoaPods or Carthage (original repository)
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
- `AS_USE_MAPKIT=0` (not accessible from Swift via SPM)
- `AS_USE_PHOTOS=0` (not accessible from Swift via SPM)
- `AS_USE_VIDEO=0` (not accessible from Swift via SPM)
- `AS_IG_LIST_KIT=1` (Objective-C implementation only)
- `AS_PIN_REMOTE_IMAGE=1` (works via SPM)

**Note:**
- Swift module `TextureIGListKitExtensions` is NOT included in binary
- Video/MapKit/Photos classes wrapped in `#if` are not exported in Swift module interface
- These features remain available via CocoaPods/Carthage or from Objective-C .m files

---

## FAQ

### Why is IGListKit API different in binary vs source?

Binary XCFrameworks cannot include Swift-only modules. Binary includes the core Objective-C implementation (`setASDKCollectionNode:`), while source distribution adds optional Swift sugar (`setCollectionNode(_:)`).

Both APIs use the same underlying implementation - only the Swift wrapper is different.

### Can I use the Swift API with binary distribution?

No. The Swift API (`TextureIGListKitExtensions`) requires source compilation. Use source distribution if you want modern Swift APIs.

### Will my CocoaPods/Carthage code work with binary?

Yes! Binary uses the same Objective-C API as CocoaPods/Carthage (`setASDKCollectionNode:`). It's a drop-in replacement.

### Why are Video/MapKit/Photos not available via SPM?

These Objective-C classes are wrapped in conditional compilation directives (`#if AS_USE_VIDEO`, `#if AS_USE_MAPKIT`, `#if AS_USE_PHOTOS`). Swift Package Manager generates module interfaces at compile time, and classes excluded by `#if` guards are not exported to the Swift module interface.

**This affects both binary and source SPM distributions.**

**To use these features:**
- Use CocoaPods or Carthage (original repository)
- Or use from Objective-C code (.m files) where the classes are still available

### What about AssetsLibrary?

Deprecated in iOS 9.0 (2015). Not available via SPM. Use Photos framework via CocoaPods/Carthage instead.

Note: Photos framework also has SPM limitations (see above).

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
