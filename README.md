# Texture (Modern SPM Fork)

Modern Swift Package Manager distribution of Texture (AsyncDisplayKit) with binary XCFramework support.

[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![Platform](https://img.shields.io/badge/platforms-iOS%2014%2B%20%7C%20tvOS%2014%2B-orange.svg)](https://github.com/3a4oT/Texture)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/TextureGroup/Texture/blob/master/LICENSE)

## Why This Fork?

This is a community-maintained fork of [TextureGroup/Texture](https://github.com/TextureGroup/Texture) focused on:

- **Binary XCFramework distribution** for faster builds
- **Modern Swift API** for IGListKit integration
- **Active SPM support** with package traits and automated releases

**Original repository:** [TextureGroup/Texture](https://github.com/TextureGroup/Texture)

---

## Key Features

| Feature | This Fork | Original |
|---------|-----------|----------|
| **Binary Distribution** | XCFramework available | Source only |
| **Swift IGListKit API** | Modern Swift extension | Objective-C only |
| **Photos (in binary)** | ✅ Included | N/A |
| **Photos (in source)** | ❌ SPM limitation | ❌ SPM limitation |
| **Video/MapKit** | Use original repo | Available (CocoaPods) |

---

## Quick Start

### Option 1: Binary Distribution (Recommended for Most Apps)

Pre-compiled XCFramework. Best for production apps and CI.

**Xcode UI (Recommended - No Manual Linking):**
1. File → Add Package Dependencies
2. URL: `https://github.com/3a4oT/Texture`
3. Version: `3.2.8` or later
4. Add product: **AsyncDisplayKitBinary**

Done! SPM automatically links Photos framework, libc++, PINRemoteImage, and IGListKit.

**Package.swift (Manual Linking Required for Libraries):**
```swift
dependencies: [
    .package(url: "https://github.com/3a4oT/Texture", from: "3.2.8")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "AsyncDisplayKitBinary", package: "Texture")
        ],
        linkerSettings: [
            .linkedLibrary("c++"),
            .linkedFramework("Photos")  // Required for ASMultiplexImageNode PHAsset support
        ]
    )
]
```

Note: linkerSettings only needed for library targets, not app targets when using Xcode UI.

**Included in binary:**
- All core nodes (ASDisplayNode, ASImageNode, ASTextNode2, ASButtonNode, etc.)
- Photos framework (ASMultiplexImageNode with PHAsset support)
- PINRemoteImage integration (image downloading/caching)
- Collection views (ASCollectionNode, ASTableNode)
- All layout specs (ASStackLayoutSpec, ASInsetLayoutSpec, etc.)
- IGListKit integration (Objective-C API)

**Not included in binary (use CocoaPods/Carthage if needed):**
- Video (ASVideoNode, ASVideoPlayerNode) - niche, heavy frameworks
- MapKit (ASMapNode) - niche, rarely used
- AssetsLibrary - Deprecated iOS 9.0

**⚠️ SPM Source Distribution Limitation:**
Video/MapKit/Photos are NOT accessible from Swift in source distribution due to SPM limitations with conditionally compiled Objective-C classes. Binary distribution has Photos available (Objective-C API).

### Option 2: Source Distribution (Same Features, Modern Swift API)

Same core features as binary, plus optional modern Swift API for IGListKit integration.

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/3a4oT/Texture", from: "3.2.8")
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

**⚠️ SPM Source Distribution Limitations:**
Video/MapKit/Photos are NOT accessible from Swift in source distribution due to SPM module interface generation limitations.

**Note:** Photos IS available in binary distribution (see Option 1 above).

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

## Migrating from CocoaPods

**For detailed migration guide, see [Binary Distribution Guide](docs/BinaryDistribution.md#migration-guide)**

Quick summary:
- ✅ Core nodes - same API
- ✅ Photos - available in **binary** distribution
- ❌ Video/MapKit - use CocoaPods/Carthage from original repo
- ⚠️ IGListKit - uses version 5.0+ (breaking changes from 4.x)

### Note for Contributors

When adding or removing source files, regenerate SPM layout:

```bash
swift scripts/generate_spm_sources_layout.swift
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
- Pre-compiled binary
- Automated GitHub Actions releases
- Checksummed releases for SPM

**Modern Swift API:**
- `TextureIGListKitExtensions` module
- Swift extension: `adapter.setCollectionNode(_:)`
- Idiomatic Swift naming conventions

**Build Optimizations:**
- TextNode2 as default (old TextNode removed)

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

### Feature Comparison

| Feature | Binary (SPM) | Source (SPM) | CocoaPods/Carthage |
|---------|-------------|--------------|-------------------|
| **Photos** | ✅ Included | ❌ Not available | ✅ Available |
| **Video/MapKit** | ❌ Not included | ❌ Not available | ✅ Available |
| **IGListKit** | Objective-C API | Swift API | Objective-C API |

**For detailed comparison**, see [Binary Distribution Guide](docs/BinaryDistribution.md)

### Future Directions

We're exploring additional distribution options based on community demand:
- **Additional binary variants** - `AsyncDisplayKitBinaryFull` with Video/MapKit for apps that need these features
- **Swift wrapper modules** - TextureVideoExtensions, TextureMapKitExtensions to provide Swift API for conditional features

**Why not include Video/MapKit by default?**
These are niche features (~10-30% of apps) that require heavy frameworks (AVFoundation, CoreMedia, MapKit). Keeping the default binary lightweight benefits the majority of users.

---

## Installation Options

### Swift Package Manager (Recommended)

**Binary (Fast):**
```swift
.package(url: "https://github.com/3a4oT/Texture", from: "3.2.8"),
.product(name: "AsyncDisplayKitBinary", package: "Texture")
```

**Source (Same Features, Swift API):**
```swift
.package(url: "https://github.com/3a4oT/Texture", from: "3.2.8"),
.product(name: "AsyncDisplayKit", package: "Texture")
```

**With Swift IGListKit API:**
```swift
.package(
    url: "https://github.com/3a4oT/Texture",
    from: "3.2.8",
    traits: [.init(name: "IGListKit")]
),
.product(name: "AsyncDisplayKit", package: "Texture"),
.product(name: "TextureIGListKitExtensions", package: "Texture")
```

### CocoaPods / Carthage

For CocoaPods and Carthage, please use the [original repository](https://github.com/TextureGroup/Texture).

**Note:** Photos is available in binary distribution. For Video/MapKit, use CocoaPods/Carthage from original repository.

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

1. Push a tag: `git tag 3.2.8 && git push origin 3.2.8`
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
