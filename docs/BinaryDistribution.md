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
- **Pros:** No compilation needed, faster builds
- **Cons:** Objective-C IGListKit API only (no Swift API)
- **Best for:** Production apps, CI builds, Objective-C codebases

### Source Distribution
- **Pros:** Modern Swift IGListKit API available
- **Cons:** Full compilation required
- **Best for:** Development, Swift codebases needing Swift API

### ⚠️ Important SPM Limitations

**Binary Distribution:**
- ✅ Photos (ASMultiplexImageNode) - Included (pre-compiled Objective-C)
- ❌ Video/MapKit - Not included (niche features)

**Source Distribution:**
- ❌ Video/MapKit/Photos - NOT accessible from Swift (SPM module interface limitation)

**Why?** These Objective-C classes are wrapped in `#if` preprocessor directives which prevents Swift Package Manager from exporting them in the module interface. Binary distribution can include them because it's pre-compiled.

**If you need Video/MapKit:**
- Use CocoaPods or Carthage (original repository)

---

## Binary vs Source Distribution

### Quick Comparison Table

| Feature | Binary Distribution | Source Distribution | CocoaPods/Carthage |
|---------|-------------------|---------------------|-------------------|
| **Build Speed** | Pre-compiled | Compiles from source | Compiles from source |
| **Core Nodes** | ✅ All included | ✅ All included | ✅ All included |
| **Photos (ASMultiplexImageNode)** | ✅ **Included** | ❌ Not available (SPM limitation) | ✅ Available |
| **Video (ASVideoNode)** | ❌ Not included | ❌ Not available (SPM limitation) | ✅ Available |
| **MapKit (ASMapNode)** | ❌ Not included | ❌ Not available (SPM limitation) | ✅ Available |
| **IGListKit Integration** | ✅ Objective-C API | ✅ **Swift API** | ✅ Objective-C API |
| **AssetsLibrary** | ❌ Deprecated iOS 9.0 | ❌ Deprecated iOS 9.0 | ❌ Deprecated iOS 9.0 |
| **Old TextNode** | ❌ Not included | ❌ Not included | ✅ Available |
| **TextNode2** | ✅ Included (default) | ✅ Included (default) | ✅ Included |
| **PINRemoteImage** | ✅ Included | ✅ Included | ✅ Included |
| **Language** | Objective-C/C++ | Objective-C/C++ + Swift | Objective-C/C++ |

**Key difference:** Binary can include Photos because it's pre-compiled Objective-C. Source distribution cannot due to SPM module interface limitations.

---

## Feature Comparison

### What's Included in Binary Distribution

The binary includes core Texture functionality:

#### Included (Ready to Use)

**Core Nodes:**
- ASDisplayNode, ASCellNode, ASScrollNode
- ASImageNode, ASNetworkImageNode, ASMultiplexImageNode
- ASTextNode2 (modern, performant text rendering)
- ASButtonNode, ASControlNode
- ASCollectionNode, ASTableNode, ASPagerNode
- All layout specs (ASStackLayoutSpec, ASInsetLayoutSpec, etc.)

**Framework Integration:**
- Photos framework (ASMultiplexImageNode with PHAsset support)
- PINRemoteImage integration (image downloading/caching)
- IGListKit integration (Objective-C API only)

**Why These Are Included:**
- Core functionality used by most apps
- Photos support is popular (gallery/photo picker apps)
- Pre-compiled binary allows Photos (unlike source distribution)

#### Not Included in Binary

**ASVideoNode, ASVideoPlayerNode (Video Support):**
- ❌ Not included in binary (niche feature)
- Heavy frameworks required (AVFoundation, CoreMedia)
- Adds significant binary size
- **Migration path:** Use CocoaPods/Carthage from original repository

**ASMapNode (MapKit Integration):**
- ❌ Not included in binary (rarely used)
- Only ~10% of apps need maps
- Requires MapKit + CoreLocation frameworks
- **Migration path:** Use CocoaPods/Carthage from original repository

**AssetsLibrary:**
- ❌ Deprecated in iOS 9.0 (2015)
- Replaced by Photos framework
- **Migration path:** Use Photos framework (included in binary)

**Old TextNode:**
- ❌ Legacy text rendering engine
- Slower than TextNode2
- **Migration path:** Use TextNode2 (included in binary)

#### SPM Source Distribution Limitations

**Photos Framework (ASMultiplexImageNode):**
- ❌ Not accessible from Swift in source distribution
- Wrapped in `#if AS_USE_PHOTOS` preprocessor directive
- Classes not exported in Swift module interface
- ✅ **Available in binary distribution** (pre-compiled Objective-C)
- **Migration path:** Use binary distribution or CocoaPods/Carthage

**Video/MapKit:**
- ❌ Not available in source distribution (SPM limitation)
- ❌ Not included in binary (niche features)
- **Migration path:** Use CocoaPods/Carthage from original repository

**TextureIGListKitExtensions (Swift API):**
- ✅ Available in source distribution only
- Modern Swift API for IGListKit
- **Binary uses:** Objective-C API (`setASDKCollectionNode:`)

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

**Use Binary Distribution if:**
- You want fastest builds (instant)
- You need Photos framework (ASMultiplexImageNode with PHAsset)
- You have an Objective-C codebase
- You're migrating from CocoaPods/Carthage
- You don't need Video/MapKit features

**Use Source Distribution if:**
- You have a Swift codebase
- You want modern Swift APIs for IGListKit
- You prefer idiomatic Swift naming
- You don't need Photos/Video/MapKit features

**Use CocoaPods or Carthage (original repository) if:**
- You need Video (ASVideoNode) features
- You need MapKit (ASMapNode) features
- You need Photos framework from Swift source code
- You're okay with longer build times

---

## For Users

### Using Binary Distribution

#### Option 1: Xcode UI (Recommended - Automatic Linking)

1. In Xcode: **File → Add Package Dependencies**
2. Enter URL: `https://github.com/3a4oT/Texture`
3. Select version: `3.2.8` or later
4. Add product: **AsyncDisplayKitBinary**

**That's it!** SPM automatically links all required frameworks and dependencies:
- ✅ Photos framework (for ASMultiplexImageNode PHAsset support)
- ✅ libc++ (C++ standard library)
- ✅ PINRemoteImage (image loading/caching)
- ✅ IGListKit + IGListDiffKit (collection view framework)

#### Option 2: Package.swift (Manual Linking Required)

For library targets, you must manually specify linkerSettings:

```swift
dependencies: [
    .package(url: "https://github.com/3a4oT/Texture", from: "3.2.8")
],
targets: [
    .target(
        name: "YourTarget",
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

**Why linkerSettings needed?** SPM doesn't transitively propagate linkerSettings from dependencies to consuming libraries, only to app targets.

**IGListKit usage with binary:**
```swift
import IGListKit
import AsyncDisplayKit

// Use Objective-C API (ASIGListSectionControllerMethods, etc.)
adapter.setASDKCollectionNode(node)
```

### Using Source Distribution with Swift API

```swift
dependencies: [
    .package(
        url: "https://github.com/TextureGroup/Texture",
        from: "3.2.8",
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

## Framework Linking Details

### Xcode UI (Automatic)

When adding the package through Xcode UI, SPM automatically links:
- **Photos** - for ASMultiplexImageNode PHAsset support
- **libc++** - C++ standard library

**No manual configuration needed!** The `AsyncDisplayKitBinaryWrapper` target in Package.swift already specifies linkerSettings, which Xcode honors automatically.

### Package.swift (Manual Required for Libraries)

If you're building a **library** (not an app), you must add linkerSettings:

```swift
linkerSettings: [
    .linkedLibrary("c++"),
    .linkedFramework("Photos")
]
```

**Why?** SPM doesn't transitively propagate linkerSettings from package dependencies to consuming library targets. App targets get them automatically.

### Features NOT in Binary

```swift
// DON'T ADD - these features are not included in binary:
// .linkedFramework("AVFoundation")   // Video not in binary
// .linkedFramework("CoreMedia")      // Video not in binary
// .linkedFramework("MapKit")         // MapKit not in binary
// .linkedFramework("CoreLocation")   // MapKit not in binary
// .linkedFramework("AssetsLibrary")  // Deprecated iOS 9.0

// To use Video/MapKit, use CocoaPods or Carthage (original repository)
```

---

## For Maintainers

### Building XCFramework

```bash
./scripts/build_xcframework.sh
```

This script:
1. Cleans previous builds
2. Resolves Carthage dependencies (PINRemoteImage, PINCache, IGListKit)
3. Builds XCFrameworks for iOS and tvOS
4. Creates ZIP archive
5. Computes checksum for Package.swift

**Build time:** 5-10 minutes on modern Mac

### Build Configuration Approach

The binary build uses **Xcode project settings** (not xcconfig files or environment variables) to configure features. This ensures flags apply ONLY to AsyncDisplayKit target, not to dependencies.

#### Configuration Locations

**1. Preprocessor Definitions (`AsyncDisplayKit.xcodeproj/project.pbxproj`)**

Search for `B35061EE1B010EDF0018CF92` (Debug) and `B35061EF1B010EDF0018CF92` (Release) configurations:

```
GCC_PREPROCESSOR_DEFINITIONS = (
    "$(inherited)",
    "AS_IG_LIST_KIT=1",
    "AS_IG_LIST_DIFF_KIT=1",
    "AS_USE_PHOTOS=1",
);
```

**2. Framework Search Paths**

```
FRAMEWORK_SEARCH_PATHS = (
    "$(inherited)",
    "$(SRCROOT)/Carthage/Build",
);
```

**3. Linker Flags**

```
OTHER_LDFLAGS = (
    "$(inherited)",
    "-framework",
    "IGListKit",
    "-framework",
    "IGListDiffKit",
    "-framework",
    "PINRemoteImage",
);
```

**Note:** PINCache and PINOperation are NOT explicitly linked - they're transitive dependencies of PINRemoteImage that Carthage resolves automatically.

**4. Feature Flag Definitions (`Source/Base/ASAvailability.h`)**

Feature flags use `#ifndef` guards to allow override:

```objc
#ifndef AS_IG_LIST_KIT
  #define AS_IG_LIST_KIT __has_include(<IGListKit/IGListKit.h>)
#endif

#ifndef AS_USE_PHOTOS
  #define AS_USE_PHOTOS 0
#endif
```

This allows project.pbxproj preprocessor definitions to override the default `__has_include()` checks.

### Current Feature Flags

**Enabled in binary (AS_*=1):**
- `AS_IG_LIST_KIT=1` - IGListKit integration (Objective-C API)
- `AS_IG_LIST_DIFF_KIT=1` - IGListDiffKit algorithms
- `AS_USE_PHOTOS=1` - Photos framework (ASMultiplexImageNode with PHAsset)
- `AS_PIN_REMOTE_IMAGE=1` - PINRemoteImage integration (auto-detected)

**Disabled in binary (AS_*=0):**
- `AS_ENABLE_TEXTNODE=0` - Old TextNode (use TextNode2 instead)
- `AS_USE_VIDEO=0` - Video support (not included)
- `AS_USE_MAPKIT=0` - MapKit support (not included)
- `AS_USE_ASSETS_LIBRARY=0` - Deprecated iOS 9.0

### How to Modify Features

#### Adding a New Feature (e.g., Video support)

1. **Edit `AsyncDisplayKit.xcodeproj/project.pbxproj`:**
   - Add `AS_USE_VIDEO=1` to `GCC_PREPROCESSOR_DEFINITIONS`
   - Add `-framework AVFoundation -framework CoreMedia` to `OTHER_LDFLAGS`

2. **Update `ASAvailability.h` (if needed):**
   ```objc
   #ifndef AS_USE_VIDEO
     #define AS_USE_VIDEO 0  // Default to disabled
   #endif
   ```

3. **Update `scripts/build_xcframework.sh` comments:**
   - Document the feature in header comments
   - Update feature list in output messages

4. **Update `docs/BinaryDistribution.md`:**
   - Add feature to "Included" list
   - Update Package.swift linkerSettings example

5. **Update `Package.swift`:**
   - Add frameworks to `AsyncDisplayKitBinaryWrapper` linkerSettings:
   ```swift
   .linkedFramework("AVFoundation"),
   .linkedFramework("CoreMedia")
   ```

#### Removing a Feature (e.g., Photos)

1. **Edit `AsyncDisplayKit.xcodeproj/project.pbxproj`:**
   - Change `AS_USE_PHOTOS=1` to `AS_USE_PHOTOS=0`

2. **Update `Package.swift`:**
   - Remove `.linkedFramework("Photos")` from wrapper

3. **Update documentation** (build script, README, BinaryDistribution.md)

### Why NOT to Use XCODE_XCCONFIG_FILE

**Problem:** Setting `XCODE_XCCONFIG_FILE` environment variable applies the xcconfig to ALL targets Carthage builds, including dependencies.

**Example failure:**
- Adding `OTHER_LDFLAGS = -framework IGListKit` to xcconfig
- Carthage tries to apply this to IGListKit's own build
- Result: IGListKit build fails (can't link against itself)

**Solution:** Use Xcode project settings directly for the AsyncDisplayKit target only.

### Dependency Linking Rules

**Explicitly link:**
- ✅ Direct dependencies used by AsyncDisplayKit code
- ✅ IGListKit - `#import <IGListKit/IGListKit.h>`
- ✅ IGListDiffKit - `IGListDiff()` function used directly
- ✅ PINRemoteImage - `#import <PINRemoteImage/...>`

**Don't explicitly link (transitive):**
- ❌ PINCache - dependency of PINRemoteImage
- ❌ PINOperation - dependency of PINRemoteImage
- Carthage resolves these automatically

**System frameworks:**
- Photos - already weak-linked in Xcode project settings
- Other system frameworks added as needed

### Troubleshooting Build Issues

**Undefined symbols for IGListKit:**
- Check `OTHER_LDFLAGS` includes `-framework IGListKit`
- Verify `FRAMEWORK_SEARCH_PATHS` includes Carthage/Build
- Ensure `AS_IG_LIST_KIT=1` in preprocessor definitions

**Header not found errors:**
- Check `FRAMEWORK_SEARCH_PATHS` includes `$(SRCROOT)/Carthage/Build`
- Verify dependencies built successfully: `ls Carthage/Build/`

**Wrong features compiled:**
- Check `GCC_PREPROCESSOR_DEFINITIONS` in project.pbxproj
- Verify ASAvailability.h has `#ifndef` guards for override
- Clean build: `rm -rf build Carthage/Build`

### Release Checklist

1. Update version in relevant files
2. Run `./scripts/build_xcframework.sh`
3. Note the checksum from build output
4. Create GitHub release with tag
5. Upload `build/Texture.xcframework.zip` to release
6. Update `Package.swift` with new URL and checksum
7. Test binary in sample project
8. Update documentation if features changed

---

## FAQ

### Why is IGListKit API different in binary vs source?

Binary XCFrameworks cannot include Swift-only modules. Binary includes the core Objective-C implementation (`setASDKCollectionNode:`), while source distribution adds optional Swift sugar (`setCollectionNode(_:)`).

Both APIs use the same underlying implementation - only the Swift wrapper is different.

### Can I use the Swift API with binary distribution?

No. The Swift API (`TextureIGListKitExtensions`) requires source compilation. Use source distribution if you want modern Swift APIs.

### Will my CocoaPods/Carthage code work with binary?

Yes! Binary uses the same Objective-C API as CocoaPods/Carthage (`setASDKCollectionNode:`). It's a drop-in replacement.

### Why are Video/MapKit/Photos not available in SPM source distribution?

These Objective-C classes are wrapped in conditional compilation directives (`#if AS_USE_VIDEO`, `#if AS_USE_MAPKIT`, `#if AS_USE_PHOTOS`). Swift Package Manager generates module interfaces at compile time, and classes excluded by `#if` guards are not exported to the Swift module interface.

**This ONLY affects SPM source distribution, not binary.**

**Photos availability:**
- ✅ Binary: Included (pre-compiled Objective-C with AS_USE_PHOTOS=1)
- ❌ Source: Not available from Swift (SPM module interface limitation)
- ✅ CocoaPods/Carthage: Available

**Video/MapKit availability:**
- ❌ Binary: Not included (niche features)
- ❌ Source: Not available from Swift (SPM module interface limitation)
- ✅ CocoaPods/Carthage: Available

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

## Future Directions

### Additional Binary Variants

We're considering additional binary distributions based on community demand:

#### AsyncDisplayKitBinaryFull (Proposed)

**What it would include:**
- Everything from default binary
- Video support (ASVideoNode, ASVideoPlayerNode)
- MapKit support (ASMapNode)
- All frameworks pre-linked

**Usage (proposed):**
```swift
dependencies: [
    .package(url: "https://github.com/3a4oT/Texture", from: "3.2.8")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "AsyncDisplayKitBinaryFull", package: "Texture")
        ],
        linkerSettings: [
            .linkedLibrary("c++"),
            .linkedFramework("Photos"),
            .linkedFramework("AVFoundation"),
            .linkedFramework("CoreMedia"),
            .linkedFramework("MapKit"),
            .linkedFramework("CoreLocation")
        ]
    )
]
```

**Trade-offs:**
- ✅ All features available
- ✅ Fast builds (pre-compiled)
- ❌ Larger binary size (~2-3 MB additional)
- ❌ More frameworks to link
- ❌ Slightly slower app launch

**Decision criteria:**
- Community demand (GitHub issues, discussions)
- Usage statistics from CocoaPods/Carthage
- Maintenance burden

### Swift Wrapper Modules

**Proposed approach:**
Create separate Swift modules that wrap conditionally compiled features:
- `TextureVideoExtensions` - Swift API for ASVideoNode
- `TextureMapKitExtensions` - Swift API for ASMapNode

**Why this helps:**
- Works around SPM module interface limitations
- Provides modern Swift API
- Optional dependencies

**Challenges:**
- Requires rewriting Objective-C code in Swift
- Maintenance of two implementations
- Breaking changes to API

**Timeline:**
No concrete timeline yet. Depends on community feedback and contributor availability.

### How to Request Features

If you need Video/MapKit in binary distribution:
1. Open GitHub issue describing your use case
2. Upvote existing issues
3. Share usage statistics from your apps

We prioritize features based on:
- Number of requests
- Usage statistics
- Community contributions
- Maintenance complexity

---

## Additional Resources

- [TextureIGListKitExtensions README](../Sources/TextureIGListKitExtensions/README.md) - Swift API details
- [Swift Package Manager Documentation](https://swift.org/package-manager/)
- [XCFramework Documentation](https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle)
- [Photos Framework Migration Guide](https://developer.apple.com/documentation/photokit)
