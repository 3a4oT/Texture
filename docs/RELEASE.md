# Release Instructions

This document explains how to create a new release of the Texture binary distribution.

## Prerequisites

- macOS with Xcode 26.0+
- Carthage installed (`brew install carthage`)
- GitHub CLI installed (`brew install gh`)
- Push access to repository
- Clean working directory (no uncommitted changes)

## Release Checklist

### 1. Prepare Release

```bash
# Ensure you're on binary-target branch
git checkout binary-target

# Pull latest changes
git pull origin binary-target

# Verify all tests pass
./build.sh spm-texture-basic
./build.sh spm-texture-iglistkit

# Clean build directory
rm -rf build/
```

### 2. Build XCFramework

```bash
# Build binary
./scripts/build_xcframework.sh

# This will:
# - Build AsyncDisplayKit.xcframework with Carthage
# - Create Texture.xcframework.zip
# - Calculate checksum
# - Output: build/Texture.xcframework.zip
```

**Expected output:**
```
================================================
Build Summary
================================================

Product Name:    Texture
XCFramework:     ./build/Texture.xcframework
ZIP Archive:     ./build/Texture.xcframework.zip
File Size:       15-18 MB
Checksum:        <64-char-hex-string>
Git Tag:         not-tagged
Git Commit:      <short-hash>
Platforms:       iOS,tvOS

Enabled Features:
  - Core AsyncDisplayKit (all nodes, layout specs, etc.)
  - Photos framework (ASMultiplexImageNode with PHAsset)
  - PINRemoteImage integration
  - IGListKit integration (Objective-C API)
  - TextNode2 (modern text rendering)

Disabled Features (use CocoaPods/Carthage if needed):
  - Video (ASVideoNode) - niche, requires AVFoundation + CoreMedia
  - MapKit (ASMapNode) - only ~10% of apps need maps
  - AssetsLibrary - deprecated in iOS 9.0
  - Old TextNode - legacy, replaced by TextNode2
```

**Save the checksum!** You'll need it for Package.swift.

### 3. Create Git Tag

```bash
# Choose semantic version (e.g., 3.2.2, 3.3.0)
VERSION="3.2.2"

# Create and push tag
git tag $VERSION
git push origin $VERSION
```

### 4. Create GitHub Release

```bash
# Create release with gh CLI
gh release create $VERSION \
  --title "$VERSION" \
  --notes "Release notes here..." \
  build/Texture.xcframework.zip

# Or manually:
# 1. Go to https://github.com/3a4oT/Texture/releases/new
# 2. Choose tag: $VERSION
# 3. Title: $VERSION
# 4. Description: Release notes
# 5. Upload: build/Texture.xcframework.zip
# 6. Publish release
```

**Release notes template:**
```markdown
## Texture $VERSION

Binary XCFramework distribution for Swift Package Manager.

### What's Included

- Core AsyncDisplayKit (all nodes, layout specs, etc.)
- Photos framework (ASMultiplexImageNode with PHAsset support)
- PINRemoteImage integration
- IGListKit integration (Objective-C API)
- TextNode2 (modern text rendering)

### Not Included

- Video (ASVideoNode) - use CocoaPods/Carthage if needed
- MapKit (ASMapNode) - use CocoaPods/Carthage if needed

### Installation

Add to your Package.swift:

\`\`\`swift
dependencies: [
    .package(url: "https://github.com/3a4oT/Texture.git", from: "$VERSION")
]

targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "AsyncDisplayKitBinary", package: "Texture")
        ],
        linkerSettings: [
            .linkedLibrary("c++"),
            .linkedFramework("Photos")
        ]
    )
]
\`\`\`

See [Binary Distribution Guide](docs/BinaryDistribution.md) for details.

### Checksums

- Texture.xcframework.zip: `<checksum-from-build-script>`
```

### 5. Update Package.swift

Get the download URL and checksum:

```bash
# URL format
URL="https://github.com/3a4oT/Texture/releases/download/$VERSION/Texture.xcframework.zip"

# Get checksum (from build script output or re-calculate)
CHECKSUM=$(swift package compute-checksum build/Texture.xcframework.zip)
echo "Checksum: $CHECKSUM"
```

Update Package.swift:

```swift
// Uncomment and update these lines in Package.swift:

.binaryTarget(
    name: "AsyncDisplayKitBinary",
    url: "https://github.com/3a4oT/Texture/releases/download/$VERSION/Texture.xcframework.zip",
    checksum: "$CHECKSUM"
),

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
        .linkedFramework("Photos"),
        .linkedLibrary("c++")
    ]
)

// And update default product:
.library(
    name: "AsyncDisplayKit",
    targets: ["AsyncDisplayKitBinaryWrapper"]  // Changed from ["AsyncDisplayKit"]
),
```

Commit and push:

```bash
git add Package.swift
git commit -m "Update Package.swift with binary target for $VERSION"
git push origin binary-target
```

### 6. Verify Release

Test the release in a sample project:

```bash
# Create test project
mkdir test-release && cd test-release
swift package init --type executable

# Add dependency
cat >> Package.swift << 'EOF'
dependencies: [
    .package(url: "https://github.com/3a4oT/Texture.git", from: "$VERSION")
],
targets: [
    .target(
        name: "test-release",
        dependencies: [
            .product(name: "AsyncDisplayKitBinary", package: "Texture")
        ]
    )
]
EOF

# Build
swift build

# Should download binary and build instantly
```

### 7. Announce Release

- Post in GitHub Discussions
- Update README.md if needed
- Notify community (Slack, Twitter, etc.)

## Troubleshooting

### Build fails with "Carthage is not installed"

```bash
brew install carthage
```

### Build fails with dependency errors

```bash
# Clean Carthage cache
rm -rf ~/Library/Caches/org.carthage.CarthageKit
rm -rf Carthage/

# Retry build
./scripts/build_xcframework.sh
```

### Checksum mismatch when testing

Make sure you:
1. Uploaded the exact file from `build/Texture.xcframework.zip`
2. Used the checksum from the build script output
3. Didn't modify the zip file after building

To recalculate checksum:
```bash
swift package compute-checksum build/Texture.xcframework.zip
```

### Binary target not found

Make sure Package.swift has:
1. Uncommented `.binaryTarget()` section
2. Correct URL pointing to GitHub release
3. Correct checksum from build script

### Photos framework not working

Users must add to linkerSettings:
```swift
.linkedFramework("Photos")
```

## Release Frequency

- **Patch releases** (3.2.x): Bug fixes, documentation updates
- **Minor releases** (3.x.0): New features, dependency updates
- **Major releases** (x.0.0): Breaking changes, major refactors

## Post-Release Tasks

- [ ] Update CHANGELOG.md
- [ ] Close related GitHub issues
- [ ] Update documentation if needed
- [ ] Monitor GitHub issues for problems
- [ ] Update examples if needed

## Rollback

If a release has critical issues:

1. Delete the GitHub release
2. Delete the git tag: `git tag -d $VERSION && git push origin :refs/tags/$VERSION`
3. Fix the issue
4. Create a new patch release

## Questions?

Open a GitHub issue or discussion.
