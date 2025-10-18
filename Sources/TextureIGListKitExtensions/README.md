# TextureIGListKitExtensions

Pure Swift implementation of IGListKit integration for Texture (AsyncDisplayKit) for Swift Package Manager.

## Quick Summary

- **What it does:** Connects `IGListAdapter` with `ASCollectionNode` in SPM builds
- **Why needed:** SPM traits don't work with Objective-C `#if` directives
- **What you get:** One Swift extension method + re-exported modules (AsyncDisplayKit, IGListKit, IGListDiffKit)
- **API:** `adapter.setCollectionNode(node)` replaces `[adapter setASDKCollectionNode:node]`
- **Version:** Uses IGListKit 5.0+ (breaking changes from 4.x)

## Overview

This module provides a single extension method to `IGListAdapter` that enables seamless integration with `ASCollectionNode`.

**Why this exists:** The original Objective-C implementation (`setASDKCollectionNode:` in `IGListAdapter+AsyncDisplayKit.mm`) doesn't compile in SPM builds because Swift Package Manager traits don't work with conditional compilation (`#if AS_IG_LIST_KIT`) in Objective-C code. This is a pure Swift reimplementation of that Objective-C code.

**Reference implementation:** This Swift code is based on the existing Objective-C implementation in:
- `Source/IGListAdapter+AsyncDisplayKit.mm`
- `Source/Private/ASIGListAdapterBasedDataSource.mm`
- `Source/Private/ASIGListAdapterBasedDataSource.h`

## ⚠️ Important: IGListKit Version Differences

**SPM uses IGListKit 5.0+ (latest major version)** which includes breaking changes compared to versions used by CocoaPods/Carthage.

- **Not a drop-in replacement** - Migration and testing required
- **API differences** - IGListKit 5.0 has breaking changes from 4.x
- **Different target** - This is specifically for SPM users
- **No Carthage/CocoaPods support planned** - We recommend migrating to SPM

If you're currently using Texture with IGListKit via CocoaPods or Carthage, please thoroughly test your integration when migrating to SPM.

## What You Get

When you `import TextureIGListKitExtensions`, you get:

1. **One extension method:**
   ```swift
   extension ListAdapter {
       @MainActor
       public func setCollectionNode(_ collectionNode: ASCollectionNode)
   }
   ```

2. **Re-exported modules** (via `public import`):
   - `AsyncDisplayKit` - All AsyncDisplayKit APIs (ASCollectionNode, ASCellNode, etc.)
   - `IGListKit` - All IGListKit APIs (ListAdapter, ListSectionController, etc.)
   - `IGListDiffKit` - Available through `IGListKit` transitive dependency (ListDiff, ListDiffable, etc.)

This means **one import gives you everything**:
```swift
import TextureIGListKitExtensions

// ListAdapter, ASCollectionNode, ListDiff, and setCollectionNode(_:) are all available!
let adapter = ListAdapter(...)
let node = ASCollectionNode(...)
adapter.setCollectionNode(node)

// IGListDiffKit also available
let result = ListDiff(oldArray: old, newArray: new, option: .equality)
```

## The Problem It Solves

**IGListKit** works with `UICollectionView`.
**Texture (AsyncDisplayKit)** works with `ASCollectionNode` (which wraps UICollectionView + async rendering).

To connect them, you need special bridging code that:
- Implements `ASCollectionDataSource` and `ASCollectionDelegate`
- Declares runtime conformance to `ASCollectionDataSourceInterop` (so ASCollectionView allows dataSource changes)
- Translates calls between IGListKit's `UICollectionView`-based API and AsyncDisplayKit's node-based API

**This module provides that bridge in pure Swift.**

## Migrating from CocoaPods

If you're migrating from CocoaPods to SPM, here's what changes:

### Before (CocoaPods)

```swift
import AsyncDisplayKit
import IGListKit

class MyViewController: UIViewController {
    let collectionNode: ASCollectionNode
    let adapter: ListAdapter

    override func viewDidLoad() {
        super.viewDidLoad()

        adapter.dataSource = self

        // Objective-C method (no import needed, works automatically)
        adapter.setASDKCollectionNode(collectionNode)
    }
}
```

### After (SPM)

```swift
import TextureIGListKitExtensions  // New import (also brings AsyncDisplayKit & IGListKit)

class MyViewController: UIViewController {
    let collectionNode: ASCollectionNode
    let adapter: ListAdapter

    override func viewDidLoad() {
        super.viewDidLoad()

        adapter.dataSource = self

        // Swift method (note the name change: setASDKCollectionNode → setCollectionNode)
        adapter.setCollectionNode(collectionNode)
    }
}
```

### Migration Checklist

1. ✅ Add `TextureIGListKitExtensions` import
2. ✅ Change `setASDKCollectionNode(_:)` to `setCollectionNode(_:)`
3. ✅ Remove separate `import AsyncDisplayKit` and `import IGListKit` (optional, as they're re-exported)

**That's it!** Everything else remains the same.

## Usage

### Basic Setup

```swift
import TextureIGListKitExtensions

class MyViewController: ASViewController<ASDisplayNode> {
    let collectionNode: ASCollectionNode
    let adapter: ListAdapter

    init() {
        let layout = UICollectionViewFlowLayout()
        self.collectionNode = ASCollectionNode(collectionViewLayout: layout)

        let updater = ListAdapterUpdater()
        self.adapter = ListAdapter(updater: updater, viewController: nil)

        super.init(node: ASDisplayNode())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        adapter.dataSource = self

        // Connect ASCollectionNode to IGListAdapter
        adapter.setCollectionNode(collectionNode)

        node.addSubnode(collectionNode)
        node.layoutSpecBlock = { [weak self] _, _ in
            guard let self = self else { return ASLayoutSpec() }
            return ASInsetLayoutSpec(
                insets: .zero,
                child: self.collectionNode
            )
        }
    }
}

extension MyViewController: ListAdapterDataSource {
    func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
        return [] // Your data objects
    }

    func listAdapter(_ listAdapter: ListAdapter, sectionControllerFor object: Any) -> ListSectionController {
        return MySectionController()
    }

    func emptyView(for listAdapter: ListAdapter) -> UIView? {
        return nil
    }
}
```

### Creating Section Controllers with ASCellNodes

Section controllers can provide `ASCellNode` instances by implementing these Objective-C methods:

```swift
import IGListKit
import AsyncDisplayKit

class MySectionController: ListSectionController {
    var item: MyItem?

    override func numberOfItems() -> Int {
        return 1
    }

    override func didUpdate(to object: Any) {
        self.item = object as? MyItem
    }
}

// Add AsyncDisplayKit support via Objective-C runtime methods
extension MySectionController {
    // Called on background queue - must be thread-safe!
    @objc func nodeBlockForItem(at index: Int) -> ASCellNodeBlock {
        let item = self.item  // Capture on calling thread
        return {
            return MyCellNode(item: item)
        }
    }

    // Provide size constraints for the node
    @objc func sizeRangeForItem(at index: Int) -> ASSizeRange {
        let width = self.collectionContext!.containerSize.width
        return ASSizeRangeMake(
            CGSize(width: width, height: 0),
            CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        )
    }
}
```

### Example Cell Node

```swift
import AsyncDisplayKit

class MyCellNode: ASCellNode {
    let textNode = ASTextNode()

    init(item: MyItem?) {
        super.init()
        automaticallyManagesSubnodes = true

        textNode.attributedText = NSAttributedString(
            string: item?.title ?? "",
            attributes: [.font: UIFont.systemFont(ofSize: 16)]
        )
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        return ASInsetLayoutSpec(
            insets: UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16),
            child: textNode
        )
    }
}
```

## How It Works Internally

The module consists of two components:

### 1. `IGListAdapterDataSourceBridge` (internal)
A bridge class that:
- Conforms to `ASCollectionDataSource`, `ASCollectionDelegate`, `ASCollectionDelegateFlowLayout`
- **Overrides `conforms(to:)`** to declare runtime conformance to:
  - `ASCollectionDataSourceInterop` - allows changing dataSource after ASCollectionView init
  - `ASCollectionDelegateInterop` - allows changing delegate after ASCollectionView init
- Forwards calls between IGListKit's adapter and AsyncDisplayKit's collection node
- Uses Objective-C runtime (`unsafeBitCast`) to call section controller methods like `nodeBlockForItemAtIndex:`

This mirrors the behavior of `ASIGListAdapterBasedDataSource` from the Objective-C implementation.

### 2. `ListAdapter.setCollectionNode(_:)` (public)
The public API that:
- Creates and retains the bridge instance (via associated objects with static key)
- Sets `collectionNode.dataSource` and `collectionNode.delegate` to the bridge
- Sets `adapter.collectionView` when the node loads (handles both loaded and unloaded states)
- Can only be called **once** per adapter (enforced with `assertionFailure`)

This replicates the behavior of `-[IGListAdapter setASDKCollectionNode:]` from the Objective-C implementation.

## Important Notes

### Thread Safety
According to AsyncDisplayKit documentation:
- Most `ASCollectionDataSource` methods are called on the **main thread**
- `collectionNode:nodeBlockForItemAtIndexPath:` can be called on **background queue**

This implementation correctly handles both cases, following the same patterns as the Objective-C version.

### Swift 6 Compatibility
This module uses **Swift 5 language mode** because it wraps Objective-C protocols (`ASCollectionDataSource`, `ASCollectionDelegate`) that lack Swift Concurrency annotations.

If you're using Swift 6, import with `@preconcurrency`:
```swift
@preconcurrency import TextureIGListKitExtensions
```

When AsyncDisplayKit adds proper `@MainActor` annotations, this module can migrate to Swift 6 mode.

### Objective-C Interop
Section controllers must implement methods using `@objc` attribute:
- `@objc func nodeBlockForItem(at:) -> ASCellNodeBlock`
- `@objc func sizeRangeForItem(at:) -> ASSizeRange`

These are called via Objective-C runtime because Swift can't directly express these method signatures in protocol form (they return blocks and use Objective-C types).

## Requirements

- iOS 14.0+ / tvOS 14.0+ / macOS 13.0+
- Swift 6.2+
- Texture (AsyncDisplayKit) via SPM with `IGListKit` trait enabled
- IGListKit 5.0+

## License

Licensed under Apache 2.0. Copyright (c) Pinterest, Inc.
