# Texture (Modern SPM & Carthage Fork)

> **This is a community fork** focused on Swift Package Manager and Carthage distribution.
>
> **Original repository:** [TextureGroup/Texture](https://github.com/TextureGroup/Texture) (full feature set with all package managers)

[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![Platform](https://img.shields.io/badge/platforms-iOS%2014%2B%20%7C%20tvOS%2014%2B-orange.svg)](https://github.com/3a4oT/Texture)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

---

## What is This Fork?

This is a **specialized fork** of Texture (AsyncDisplayKit) that:

### ✅ Maintains
- **Swift Package Manager** (source & binary)
- **Carthage** (XCFramework distribution)
- **Core Texture functionality** (nodes, layouts, collections)
- **IGListKit integration**
- **PINRemoteImage integration**

### ❌ Removed (in this fork)
- **21 example projects** - Kept only SPM-focused examples
- **Legacy infrastructure** - Removed outdated tooling

### 🎯 Why This Fork Exists

1. **Cleaner SPM/Carthage experience** - Streamlined for modern package managers
2. **Binary XCFramework** - Pre-compiled for faster builds
3. **Modern CI** - SPM and Carthage only
4. **Honest about limitations** - Clear documentation on what works and what doesn't

**If you need Video/MapKit or the full original codebase:** Use the [original repository](https://github.com/TextureGroup/Texture).

---

## Distribution Methods

| Method | Type | Build Time | Use Case |
|--------|------|-----------|----------|
| **SPM Source** | Static library | 2-5 min | Development, debugging |
| **SPM Binary** | Dynamic framework (XCFramework) | Instant | Production, CI |
| **Carthage** | Dynamic framework (XCFramework) | 5-10 min | Traditional workflow |

### Key Differences

**Static vs Dynamic:**

**SPM Source (Static):**
- Compiled into your app binary
- No separate framework file
- Smaller disk footprint
- Debug-friendly

**SPM Binary / Carthage (Dynamic):**
- Separate `.framework` file
- Shared between targets
- Faster incremental builds
- Pre-compiled (Binary only)

**IGListKit Always Required:**

This fork differs from the original by **always including IGListKit as a required dependency**. The original Texture allows using AsyncDisplayKit without IGListKit, but this fork simplifies the architecture by making IGListKit mandatory:

- ✅ **This fork:** IGListKit always included (simplified, opinionated)
- ⚠️ **Original:** IGListKit is optional (more flexible, more complex)

---

## Quick Start

### Option 1: SPM Binary (Recommended for Apps)

Pre-compiled XCFramework. Instant build time.

**Xcode UI:**
1. File → Add Package Dependencies
2. URL: `https://github.com/3a4oT/Texture`
3. Version: `4.0.0` or later
4. Add product: **AsyncDisplayKitBinary**

**Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/3a4oT/Texture", from: "4.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "AsyncDisplayKitBinary", package: "Texture")
        ]
    )
]
```

### Option 2: SPM Source

Same features, but compiles from source. Useful for debugging.

```swift
dependencies: [
    .package(url: "https://github.com/3a4oT/Texture", from: "4.0.0")
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

### Option 3: Carthage

For teams using Carthage workflow.

```
github "3a4oT/Texture" ~> 4.0.0
```

Then:
```bash
carthage update --use-xcframeworks --platform iOS
```

---

## What's Included

### ✅ Available Features

| Feature | SPM Source | SPM Binary | Carthage |
|---------|-----------|-----------|----------|
| **Core Nodes** | ✅ Static | ✅ Dynamic | ✅ Dynamic |
| **Collections** | ✅ Static | ✅ Dynamic | ✅ Dynamic |
| **Layout Specs** | ✅ Static | ✅ Dynamic | ✅ Dynamic |
| **TextNode2** | ✅ Static | ✅ Dynamic | ✅ Dynamic |
| **PINRemoteImage** | ✅ Static | ✅ Dynamic | ✅ Dynamic |
| **IGListKit** | ✅ Swift API only* | ✅ ObjC API only** | ✅ ObjC API only** |
| **Photos** | ❌ | ✅ Dynamic | ✅ Dynamic |

\* SPM Source: Use `TextureIGListKitExtensions` module → `adapter.setCollectionNode(node)`  
\*\* Binary/Carthage: Use native Objective-C API → `adapter.setASDKCollectionNode(node)`  
⚠️ **API methods differ** - not drop-in replacements (see IGListKit Integration section)

**Core Nodes:** ASDisplayNode, ASImageNode, ASTextNode2, ASButtonNode, ASControlNode, ASScrollNode, etc.

**Collections:** ASCollectionNode, ASTableNode, ASPagerNode

**Layout Specs:** ASStackLayoutSpec, ASInsetLayoutSpec, ASCenterLayoutSpec, ASRatioLayoutSpec, etc.

### ❌ Not Included (By Design)

| Feature | Reason | Alternative |
|---------|--------|-------------|
| **Video** (ASVideoNode) | Niche feature, heavy frameworks | Use [original repo](https://github.com/TextureGroup/Texture) |
| **MapKit** (ASMapNode) | Niche feature, rarely used | Use [original repo](https://github.com/TextureGroup/Texture) |
| **AssetsLibrary** | Deprecated iOS 9.0 | Use Photos framework |
| **Old TextNode** | Legacy, slower | Use TextNode2 (included) |

**Why not include Video/MapKit?**
- Used by ~10-30% of apps
- Require heavy system frameworks (AVFoundation, CoreMedia, MapKit)
- Keeping the binary lightweight benefits the majority

---

## Photos Framework Support

**SPM Source:** ❌ Not available due to Swift/Objective-C interop limitations
**SPM Binary:** ✅ Available (Objective-C API only)
**Carthage:** ✅ Available (full support)

If you need Photos in SPM, use Binary distribution:

```swift
import AsyncDisplayKit
import Photos

// Works in Binary, not in Source
let imageNode = ASMultiplexImageNode()
imageNode.asset = PHAsset() // ✅ Binary ❌ Source
```

---

## IGListKit Integration

IGListKit is **always required** in this fork.

### ⚡ Quick Start

**SPM Source Distribution (Swift only):**
```swift
import TextureIGListKitExtensions  // Re-exports AsyncDisplayKit + IGListKit

let adapter = ListAdapter(updater: ..., viewController: ...)
let node = ASCollectionNode()
adapter.setCollectionNode(node)  // ✅ Swift API (only option)
```

**SPM Binary / Carthage (Objective-C only):**
```swift
import AsyncDisplayKit
import IGListKit

let adapter = ListAdapter(updater: ..., viewController: ...)
let node = ASCollectionNode()
adapter.setASDKCollectionNode(node)  // ✅ Objective-C API (only option)
```

**⚠️ Method names differ** - not drop-in replacements between Source and Binary/Carthage.

### 📋 API Availability

| API | SPM Source | SPM Binary | Carthage |
|-----|------------|------------|----------|
| `adapter.setASDKCollectionNode(node)` | ❌ | ✅ | ✅ |
| `adapter.setCollectionNode(node)` via `TextureIGListKitExtensions` | ✅ Required | ❌ | ❌ |

**⚠️ Method names differ** - not drop-in replacements between distributions.

**📚 Detailed Documentation:**
- [TextureIGListKitExtensions Module Documentation](Sources/TextureIGListKitExtensions/README.md)
- [Binary Distribution Guide](docs/BinaryDistribution.md)

---

## Migration Guide

### From Original Repository → This Fork

**If you use Video/MapKit:** Stay with [original repository](https://github.com/TextureGroup/Texture).

**If you don't need Video/MapKit:**

1. Remove Podfile and `pod install` artifacts
2. Add SPM dependency (see Quick Start)
3. Update imports if needed
4. ✅ Done - Same API

### From Original Texture (SPM) → This Fork

**No changes needed!** This fork is backward compatible with the original SPM distribution.

### Binary vs Source?

| Choose Binary if... | Choose Source if... |
|-------------------|-------------------|
| You want instant builds | You need to debug Texture code |
| You use Photos framework | You don't need Photos |
| You're building for production | You're actively developing |
| You trust pre-compiled binaries | You prefer compiling yourself |

---

## Examples

See `examples/` directory:

- **SPMBasic** - Basic usage with SPM
- **SPMWithIGListKit** - IGListKit integration
- **ASIGListKitSPM** - Complete iOS app

**Note:** 21 example projects were removed from this fork to focus on SPM/Carthage. See [original repository](https://github.com/TextureGroup/Texture) for full examples.

---

## Comparison: This Fork vs Original

| Feature | This Fork | Original |
|---------|-----------|----------|
| **Package Managers** | SPM + Carthage only | SPM + Carthage + CocoaPods |
| **IGListKit** | ✅ Always required | ⚠️ Optional |
| **SPM Source** | ✅ Static library | ✅ Static library |
| **SPM Binary** | ✅ XCFramework | ❌ Not available |
| **Carthage** | ✅ XCFramework | ✅ Dynamic framework |
| **Photos (SPM Binary)** | ✅ Available | N/A |
| **Photos (SPM Source)** | ❌ Not available | ❌ Not available |
| **Video/MapKit** | ❌ Not included | ✅ Available |
| **CI/CD** | SPM + Carthage | All package managers |

**When to use original repository:**
- You need the full original codebase
- You need Video (ASVideoNode) or MapKit (ASMapNode)
- You want to use AsyncDisplayKit WITHOUT IGListKit
- You want the officially maintained version

**When to use this fork:**
- You use SPM or Carthage exclusively
- You want pre-compiled binary (faster builds)
- You're OK with IGListKit being always included
- You don't need Video/MapKit
- You prefer a streamlined SPM/Carthage-focused repository

---

## Documentation

### Fork-Specific
- [Binary Distribution Guide](docs/BinaryDistribution.md) - Detailed comparison
- [IGListKit Swift API](Sources/TextureIGListKitExtensions/README.md) - Modern Swift extensions

### Original Texture Docs
- [Getting Started](http://texturegroup.org/docs/getting-started.html)
- [Layout Guide](http://texturegroup.org/docs/layout2-quickstart.html)
- [Node Hierarchy](http://texturegroup.org/docs/node-overview.html)
- [Original README](docs/ORIGINAL_README.md)

---

## Contributing

### To This Fork

Welcome contributions for:
- SPM/Carthage improvements
- Binary distribution enhancements
- Documentation
- Bug fixes

### To Core Texture

Please contribute to [upstream repository](https://github.com/TextureGroup/Texture).

We periodically sync with upstream for core improvements.

---

## Building XCFramework

For binary distribution:

```bash
./scripts/build_xcframework.sh
```

Creates `build/Texture.xcframework.zip` with checksum for SPM.

See: [Binary Distribution Guide](docs/BinaryDistribution.md#building-xcframework)

---

## Releases

Automated via GitHub Actions:

1. Push tag: `git tag 4.0.0 && git push origin 4.0.0`
2. GitHub Actions builds XCFramework
3. Creates release with binary
4. Generates SPM checksum

See: [.github/workflows/release-xcframework.yml](.github/workflows/release-xcframework.yml)

---

## License

Apache License 2.0

Copyright (c) Pinterest, Inc.
Copyright (c) Facebook, Inc. and its affiliates.

See [LICENSE](LICENSE) for details.

---

## Acknowledgments

Built on the excellent work by:
- [Pinterest Engineering](https://github.com/pinterest) - Current maintainers of original repo
- [Facebook](https://github.com/facebook) - Original creators
- [TextureGroup Community](https://github.com/TextureGroup) - Contributors

**Upstream:** [TextureGroup/Texture](https://github.com/TextureGroup/Texture)

---

## Links

- **This Fork:** [github.com/3a4oT/Texture](https://github.com/3a4oT/Texture)
- **Original Repo:** [github.com/TextureGroup/Texture](https://github.com/TextureGroup/Texture)
- **Documentation:** [texturegroup.org](http://texturegroup.org)
- **Issues:** [Report fork-specific issues](https://github.com/3a4oT/Texture/issues)

---

## FAQ

**Q: Why fork instead of contributing to original?**
A: This fork has a different philosophy (SPM/Carthage-only, cleaner codebase). The original repository maintains broader compatibility and full feature set.

**Q: Will you sync with upstream?**
A: Yes, we periodically pull core Texture improvements from upstream.

**Q: Can I use this in production?**
A: Yes! The core Texture code is the same. Only the distribution method differs.

**Q: What if I need Video/MapKit?**
A: Use the [original repository](https://github.com/TextureGroup/Texture).

**Q: Is this fork maintained?**
A: Yes, by the community. For core Texture bugs, report to [upstream](https://github.com/TextureGroup/Texture).

---

**Made with ❤️ for the iOS community**
