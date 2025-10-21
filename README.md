# Texture (Modern SPM Fork)

Modern Swift Package Manager distribution of Texture (AsyncDisplayKit) with binary XCFramework support and optimizations for iOS 14+.

[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![Platform](https://img.shields.io/badge/platforms-iOS%2014%2B%20%7C%20tvOS%2014%2B-orange.svg)](https://github.com/3a4oT/Texture)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/TextureGroup/Texture/blob/master/LICENSE)

## Why This Fork?

This is a community-maintained fork of [TextureGroup/Texture](https://github.com/TextureGroup/Texture) focused on:

- **Binary XCFramework distribution** for faster builds (save 2-5 minutes per clean build)
- **Modern Swift API** for IGListKit integration
- **iOS 14+ optimization** with deprecated code removed
- **Active SPM support** with package traits and automated releases

**Original repository:** [TextureGroup/Texture](https://github.com/TextureGroup/Texture)

---

## Key Features

| Feature | This Fork | Original |
|---------|-----------|----------|
| **Binary Distribution** | XCFramework available | Source only |
| **Build Time (binary)** | Instant | N/A |
| **Build Time (source)** | 2-5 min | 2-5 min |
| **Swift IGListKit API** | Modern Swift extension | Objective-C only |
| **iOS Minimum** | 14.0 | 12.0 |
| **SPM Video/MapKit/Photos** | Not available (SPM limitation) | Not available (SPM limitation) |
| **Video/MapKit/Photos via CocoaPods** | Use original repo | Available |
| **Deprecated Code** | Removed | Included |
| **Automated Releases** | GitHub Actions | Manual |

---

## Quick Start

### Option 1: Binary Distribution (Recommended for Most Apps)

Fast builds with pre-compiled XCFramework. Best for production apps and CI.

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/3a4oT/Texture", from: "3.2.1")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "AsyncDisplayKitBinary", package: "Texture")
        ],
        linkerSettings: [
            .linkedLibrary("c++")
        ]
    )
]
```

**Included in binary:**
- All core nodes (ASDisplayNode, ASImageNode, ASTextNode2, ASButtonNode, etc.)
- PINRemoteImage integration (image downloading/caching)
- Collection views (ASCollectionNode, ASTableNode)
- All layout specs (ASStackLayoutSpec, ASInsetLayoutSpec, etc.)
- IGListKit integration (Objective-C API)

**⚠️ Not available via SPM (both binary and source):**
- Video (ASVideoNode, ASVideoPlayerNode) - SPM limitation
- MapKit (ASMapNode) - SPM limitation
- Photos framework integration - SPM limitation
- AssetsLibrary - Deprecated iOS 9.0

**If you need Video/MapKit/Photos features:**
- Use CocoaPods or Carthage (full feature support)
- Or use these features from Objective-C code (.m files)

**Build time:** Instant (no compilation)

### Option 2: Source Distribution (Same Features, Modern Swift API)

Same core features as binary, plus optional modern Swift API for IGListKit integration.

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/3a4oT/Texture", from: "3.2.1")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "AsyncDisplayKit", package: "Texture")
        ]
    )
]
```

**Default Features (included automatically):**
- Core AsyncDisplayKit (ASDisplayNode, ASImageNode, ASTextNode2, ASButtonNode, etc.)
- PINRemoteImage integration (ASPINRemoteImageDownloader)
- Collection views (ASCollectionNode, ASTableNode)
- Layout specs (ASStackLayoutSpec, ASInsetLayoutSpec, etc.)
- TextNode2 (modern text rendering, replaces legacy TextNode)

**Optional Features (enable via traits):**
- IGListKit integration (advanced collection views with modern Swift API)

**⚠️ SPM Limitations:**
Video (ASVideoNode), MapKit (ASMapNode), and Photos features are **not available** via Swift Package Manager due to technical limitations. These Objective-C classes are wrapped in conditional compilation directives (`#if AS_USE_VIDEO`) which prevents them from being exported in the Swift module interface.

**If you need Video/MapKit/Photos features:**
- Use **CocoaPods** or **Carthage** (full feature support)
- Or use these features from **Objective-C code** (.m files)

**Future directions:** We're exploring solutions like Swift wrapper modules (TextureVideoExtensions, TextureMapKitExtensions) to provide Swift API for these features via SPM.

**Build time:** 2-5 minutes

---

## IGListKit Integration

### Binary Distribution: Objective-C API

```swift
import IGListKit
import AsyncDisplayKit

let adapter = ListAdapter(updater: ..., viewController: ...)
let node = ASCollectionNode()

// Objective-C API (same as CocoaPods/Carthage)
adapter.setASDKCollectionNode(node)
```

### Source Distribution: Modern Swift API

```swift
import TextureIGListKitExtensions  // Includes everything

let adapter = ListAdapter(updater: ..., viewController: ...)
let node = ASCollectionNode()

// Modern Swift API
adapter.setCollectionNode(node)
```

Read more: [IGListKit Integration Guide](Sources/TextureIGListKitExtensions/README.md)

---

## Migrating from CocoaPods to SPM

If you're migrating from CocoaPods, here's how the subspecs map to SPM features:

| Feature | CocoaPods | SPM | Notes |
|---------|-----------|-----|-------|
| **Core** | `pod 'Texture'` (default) | `.product(name: "AsyncDisplayKit", ...)` | ✅ Always included |
| **PINRemoteImage** | Included by default | Always included | ✅ Same behavior |
| **Video** | Included by default | **Not available** | ❌ SPM limitation (see above) |
| **MapKit** | Included by default | **Not available** | ❌ SPM limitation (see above) |
| **Photos** | Included by default | **Not available** | ❌ SPM limitation (see above) |
| **AssetsLibrary** | Included by default | **Removed** | ❌ Deprecated iOS 9.0, use Photos |
| **IGListKit** | `pod 'Texture/IGListKit'` | Optional trait + product | ⚠️ Uses IGListKit 5.0+ |
| **TextNode2** | `pod 'Texture/TextNode2'` | Enabled by default | ✅ Modern TextNode used |
| **Yoga** | `pod 'Texture/Yoga'` | Not supported | Add as separate dependency |

**Key differences:**
- **TextNode2 is default**: SPM uses the modern TextNode implementation automatically (no legacy TextNode)
- ❌ **Video/MapKit/Photos not available**: Due to Swift Package Manager limitations with conditionally compiled Objective-C classes
- ❌ **AssetsLibrary removed**: Deprecated in iOS 9.0, use Photos framework instead
- ⚠️ **IGListKit version**: SPM uses IGListKit 5.0+ instead of 4.x (breaking changes)
- ℹ️ **Yoga**: Not integrated in SPM - add Yoga as a separate dependency if needed

### Note for Contributors

When adding or removing source files in the `Source/` directory, you must regenerate the SPM symlink structure:

```bash
# Regenerate SPM layout
swift scripts/generate_spm_sources_layout.swift

# Commit the generated changes
git add spm/Sources
git commit -m "Update SPM layout for new/removed files"
```

---

## Documentation

### Fork-Specific Documentation

- **[Binary Distribution Guide](docs/BinaryDistribution.md)** - Comprehensive guide on binary vs source, feature comparison, API differences
- **[IGListKit Swift API](Sources/TextureIGListKitExtensions/README.md)** - Modern Swift API for IGListKit integration

### Original Texture Documentation

- **[Getting Started](http://texturegroup.org/docs/getting-started.html)** - Core concepts and basics
- **[Layout Guide](http://texturegroup.org/docs/layout2-quickstart.html)** - Layout system documentation
- **[Node Hierarchy](http://texturegroup.org/docs/node-overview.html)** - Understanding nodes
- **[Original README](docs/ORIGINAL_README.md)** - Full original README preserved

---

## What's Different From Original?

### Added Features

**Binary XCFramework Distribution:**
- Pre-compiled binary for instant builds
- Optimized for iOS 14+ (smaller size)
- Automated GitHub Actions releases
- Checksummed releases for SPM

**Modern Swift API:**
- `TextureIGListKitExtensions` module
- Swift extension: `adapter.setCollectionNode(_:)`
- Idiomatic Swift naming conventions

**Build Optimizations:**
- TextNode2 as default (old TextNode removed)
- Optimized for iOS 14+
- Smaller binary size

**Developer Experience:**
- Automated release workflow
- Detailed binary distribution docs
- Clear migration guides

### What's Available

**Core functionality in both binary and source:**
- All standard nodes (ASDisplayNode, ASImageNode, ASTextNode2, etc.)
- Collection views (ASCollectionNode, ASTableNode, ASPagerNode)
- IGListKit integration (Objective-C API in binary, Swift API in source)
- All layout specs
- PINRemoteImage integration

### SPM Limitations (Both Binary and Source)

**Not available from Swift code:**
- Video support (ASVideoNode, ASVideoPlayerNode) - use CocoaPods/Carthage
- MapKit (ASMapNode) - use CocoaPods/Carthage
- Photos framework integration - use CocoaPods/Carthage
- AssetsLibrary - deprecated iOS 9.0

These features are wrapped in `#if` preprocessor directives which prevents Swift Package Manager from exporting them in the module interface. They remain available via CocoaPods/Carthage or from Objective-C .m files.

---

## Installation Options

### Swift Package Manager (Recommended)

**Binary (Fast):**
```swift
.package(url: "https://github.com/3a4oT/Texture", from: "3.2.1"),
.product(name: "AsyncDisplayKitBinary", package: "Texture")
```

**Source (Same Features, Swift API):**
```swift
.package(url: "https://github.com/3a4oT/Texture", from: "3.2.1"),
.product(name: "AsyncDisplayKit", package: "Texture")
```

**With Swift IGListKit API:**
```swift
.package(
    url: "https://github.com/3a4oT/Texture",
    from: "3.2.1",
    traits: [.init(name: "IGListKit")]
),
.product(name: "AsyncDisplayKit", package: "Texture"),
.product(name: "TextureIGListKitExtensions", package: "Texture")
```

### CocoaPods / Carthage

For CocoaPods and Carthage, please use the [original repository](https://github.com/TextureGroup/Texture).

**Note:** If you need Video (ASVideoNode), MapKit (ASMapNode), or Photos features, you must use CocoaPods or Carthage as these are not available via SPM due to technical limitations.

---

## Migration Guide

### From Original Texture (SPM)

**No changes needed!** This fork is backward compatible.

Source distribution uses the same API as the original.

### From CocoaPods/Carthage to This Fork

**For Objective-C projects:**
1. Switch to SPM binary distribution
2. No code changes needed (same API)

**For Swift projects:**
1. Choose binary (Objective-C API) or source (Swift API)
2. If using source, update imports and API calls (see docs)

Read: [Binary Distribution Guide](docs/BinaryDistribution.md)

---

## Examples

Check the `examples/` directory for sample projects:

- **SPMBasic** - Basic AsyncDisplayKit usage with SPM
- **SPMWithIGListKit** - IGListKit integration examples
- **ASIGListKitSPM** - Complete iOS app with IGListKit

---

## Contributing

We welcome contributions to this fork!

### Focus Areas for This Fork

- Binary distribution improvements
- Swift API enhancements
- iOS 14+ optimizations
- SPM-specific features
- Documentation improvements

### For Core Texture Changes

Please contribute to the [upstream repository](https://github.com/TextureGroup/Texture).

We periodically sync with upstream to get core improvements.

### How to Contribute

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## Releases

This fork uses automated releases via GitHub Actions:

1. Push a tag: `git tag 3.2.1 && git push origin 3.2.1`
2. GitHub Actions builds XCFramework
3. Creates release with binary artifact
4. Generates checksum for SPM

See: [Release Workflow](.github/workflows/release-xcframework.yml)

---

## License

Same as original: Apache License 2.0

Copyright (c) Pinterest, Inc.
Copyright (c) Facebook, Inc. and its affiliates.

See [LICENSE](LICENSE) for details.

---

## Acknowledgments

This fork is built on top of the excellent work by:
- [Pinterest Engineering](https://github.com/pinterest) - Current maintainers
- [Facebook](https://github.com/facebook) - Original creators
- [TextureGroup Community](https://github.com/TextureGroup) - Contributors

**Upstream repository:** [TextureGroup/Texture](https://github.com/TextureGroup/Texture)

---

## Links

- **This Fork:** [github.com/3a4oT/Texture](https://github.com/3a4oT/Texture)
- **Original Repo:** [github.com/TextureGroup/Texture](https://github.com/TextureGroup/Texture)
- **Documentation:** [texturegroup.org](http://texturegroup.org)
- **Binary Guide:** [docs/BinaryDistribution.md](docs/BinaryDistribution.md)
- **Issues:** [Report issues specific to this fork](https://github.com/3a4oT/Texture/issues)

---

**Made with ❤️ for the iOS community**
