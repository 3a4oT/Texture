# SPM With IGListKit Example

This example demonstrates how to use the IGListKit trait with Texture via Swift Package Manager.

## What This Example Tests

This example verifies that when you enable the IGListKit trait in your Package.swift, the IGListKit dependency is resolved and available for use alongside Texture's ASCollectionNode.

## Package.swift Trait Syntax

```swift
dependencies: [
    .package(
        url: "https://github.com/TextureGroup/Texture.git",
        from: "3.3.0",
        traits: [
            .init(name: "IGListKit")  // Enable IGListKit trait
        ]
    )
]
```

## What Gets Enabled

When the IGListKit trait is enabled:

1. **IGListKit dependency** is resolved and added to your project
2. **IGListDiffKit** (part of IGListKit) is also available
3. You can use both **Texture** (ASCollectionNode, ASDisplayNode, etc.) and **IGListKit** (ListAdapter, ListSectionController, etc.) together

## Building

```bash
swift build
```

Or with xcodebuild:

```bash
xcodebuild -scheme SPMWithIGListKit -sdk iphonesimulator -destination 'platform=iOS Simulator,OS=26.0,name=iPhone 17' build
```

## Running Tests

```bash
swift test
```

Or with xcodebuild:

```bash
xcodebuild -scheme SPMWithIGListKit -sdk iphonesimulator -destination 'platform=iOS Simulator,OS=26.0,name=iPhone 17' test
```

## Tests

The test suite verifies:

- ✓ IGListKit dependency is resolved and classes are available
- ✓ Basic IGListKit objects (ListAdapter, ListAdapterUpdater) can be created
- ✓ ASCollectionNode from Texture is available
- ✓ Both frameworks can be used together

## Usage in Your App

```swift
import AsyncDisplayKit
import IGListKit

// Use Texture's ASCollectionNode
let layout = UICollectionViewFlowLayout()
let collectionNode = ASCollectionNode(collectionViewLayout: layout)

// Use IGListKit's ListAdapter
let updater = ListAdapterUpdater()
let adapter = ListAdapter(updater: updater, viewController: self)

// Connect them (requires additional integration code from Texture)
// See Texture source: IGListAdapter+AsyncDisplayKit.h
```

## Note

The Texture+IGListKit integration APIs (`IGListAdapter.setASDKCollectionNode(_:)`, `ASIGListSectionControllerMethods`, etc.) are Objective-C extensions that may require additional bridging to use from Swift. This example focuses on verifying that the trait enables the IGListKit dependency correctly.

## Learn More

- **IGListKit**: https://github.com/Instagram/IGListKit
- **Texture Documentation**: http://texturegroup.org
