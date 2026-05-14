//
//  IGListAdapter+Texture.swift
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation
import ObjectiveC
import os.log
public import AsyncDisplayKit
public import IGListKit
public import IGListDiffKit

/// Subsystem-scoped log used by the section-count guard in
/// `ListAdapter.performUpdatesWithFallback`. Reads in Console.app under
/// `subsystem: TextureIGListKitExtensions`, `category: iglistkit-guard`.
private let iglistkitGuardLog = OSLog(subsystem: "TextureIGListKitExtensions",
                                      category: "iglistkit-guard")

/// Pure Swift data source bridge between IGListKit and AsyncDisplayKit
///
/// ## Thread Safety (based on AsyncDisplayKit documentation)
///
/// According to ASCollectionNode.h documentation:
/// - Most `ASCollectionDataSource` methods are called on the **main thread**
/// - `collectionNode:nodeBlockForItemAtIndexPath:` is documented as "Must be thread-safe
///   (can be called on the main thread or a background queue)"
/// - See ASCollectionNode.h lines 601 and 746-758 for official documentation
///
/// ## Why Swift 5 mode?
///
/// This module uses Swift 5 language mode because it wraps Objective-C protocols
/// (`ASCollectionDataSource`, `ASCollectionDelegate`) that lack Swift Concurrency annotations.
/// Using Swift 6 mode would require unsafe workarounds (`nonisolated(unsafe)`,
/// `MainActor.assumeIsolated`) that could lead to runtime crashes if assumptions change.
///
/// When AsyncDisplayKit adds proper `@MainActor` annotations to its protocols,
/// this module can safely migrate to Swift 6 mode.
///
/// Consumers using Swift 6 can import this module with:
/// ```swift
/// @preconcurrency import TextureIGListKitExtensions
/// ```
// Bridge class that manually declares conformance to Interop protocols via runtime
@objc internal class IGListAdapterDataSourceBridge: NSObject, ASCollectionDataSource, ASCollectionDelegate, ASCollectionDelegateFlowLayout {

    // Override to manually declare protocol conformance at runtime (instance method)
    override func conforms(to aProtocol: Protocol) -> Bool {
        // Declare conformance to ASCollectionDataSourceInterop and ASCollectionDelegateInterop
        if let interopDataSource = NSProtocolFromString("ASCollectionDataSourceInterop"),
           protocol_isEqual(aProtocol, interopDataSource) {
            return true
        }
        if let interopDelegate = NSProtocolFromString("ASCollectionDelegateInterop"),
           protocol_isEqual(aProtocol, interopDelegate) {
            return true
        }
        return super.conforms(to: aProtocol)
    }
    weak var listAdapter: ListAdapter?
    weak var collectionDelegate: ASCollectionDelegate?
    private var dataSource: UICollectionViewDataSource? {
        return listAdapter as? UICollectionViewDataSource
    }
    private var delegate: UICollectionViewDelegateFlowLayout? {
        return listAdapter as? UICollectionViewDelegateFlowLayout
    }

    /// Section controller captured during `shouldBatchFetchForCollectionNode:` so that
    /// `willBeginBatchFetchWithContext:` (called on a background queue) can forward
    /// to the same controller without re-querying the list adapter.
    ///
    /// Per the original Obj-C bridge contract, those two calls are guaranteed not to
    /// execute in parallel, so a plain weak reference (no lock) is safe.
    private weak var sectionControllerForBatchFetching: ListSectionController?

    /// AsyncDisplayKit's `ASCollectionDataSourceInterop` class contract: signals that
    /// node-backed cells should still be dequeued through the standard collection-view
    /// path. Required for proper interop between IGListKit's cell lifecycle and
    /// ASCollectionNode's async rendering — without it, IGListKit can route
    /// willDisplay/didEndDisplaying callbacks to indexPaths whose section controller
    /// has already been invalidated.
    @objc static var dequeuesCellsForNodeBackedItems: Bool { true }

    init(listAdapter: ListAdapter, collectionDelegate: ASCollectionDelegate?) {
        self.listAdapter = listAdapter
        self.collectionDelegate = collectionDelegate
        super.init()

        // Configure updater for AsyncDisplayKit compatibility.
        //
        // IGListKit 5.0+ removed `allowsBackgroundReloading` (the flag the old Obj-C
        // bridge used to keep IGListKit on the batch-updates path). The remaining knob
        // is `allowsBackgroundDiffing`, which moves diff computation off-main.
        //
        // `allowsBackgroundDiffing = true` is **unsafe** with `ASCollectionNode`:
        // IGListKit snapshots `numberOfSectionsInCollectionView:` when scheduling the
        // background diff and re-reads it on the main thread when applying the result.
        // ASCollectionNode-backed adapters routinely mutate their object array between
        // those two points (push updates, model refresh, navigation), producing the
        // classic `IGListBatchUpdateTransaction.m:145` "section count mismatch" and
        // `ASCollectionInvalidUpdateException` crashes seen in production.
        //
        // Diffing must stay on the main thread for AsyncDisplayKit consumers.
        if let updater = listAdapter.updater as? ListAdapterUpdater {
            updater.allowsBackgroundDiffing = false
        }
    }

    // MARK: - Helper Methods

    private func sectionController(forSection section: Int) -> ListSectionController? {
        guard let listAdapter = listAdapter,
              let object = listAdapter.object(atSection: section) else {
            return nil
        }
        return listAdapter.sectionController(for: object)
    }

    /// Returns the section's `supplementaryViewSource` as an `NSObject` ready for
    /// selector-based dispatch. Mirrors `-supplementaryElementSourceForSection:`
    /// in the original Obj-C bridge. Selector dispatch is used (instead of Swift
    /// protocol bridging) because `ASSupplementaryNodeSource` methods are
    /// `@optional` Obj-C protocol methods, and matching the rest of this file's
    /// dispatch style keeps the bridging consistent.
    private func supplementarySource(forSection section: Int) -> NSObject? {
        guard let ctrl = sectionController(forSection: section) else { return nil }
        return ctrl.supplementaryViewSource as? NSObject
    }

    // MARK: - ASCollectionDataSource

    func collectionNode(_ collectionNode: ASCollectionNode, numberOfItemsInSection section: Int) -> Int {
        guard let dataSource = dataSource else { return 0 }
        let collectionView = collectionNode.view as! UICollectionView
        return dataSource.collectionView(collectionView, numberOfItemsInSection: section)
    }

    func numberOfSections(in collectionNode: ASCollectionNode) -> Int {
        guard let dataSource = dataSource else { return 0 }
        let collectionView = collectionNode.view as! UICollectionView
        return dataSource.numberOfSections?(in: collectionView) ?? 1
    }

    // This method must be thread-safe per AsyncDisplayKit documentation:
    // "Must be thread-safe (can be called on the main thread or a background queue)"
    func collectionNode(_ collectionNode: ASCollectionNode, nodeBlockForItemAt indexPath: IndexPath) -> ASCellNodeBlock {
        // Capture section controller on calling thread (could be main or background)
        guard let sectionController = sectionController(forSection: indexPath.section) else {
            return {
                let node = ASCellNode()
                node.style.preferredSize = CGSize(width: 50, height: 50)
                return node
            }
        }

        // Check if section controller conforms to ASSectionController protocol
        // ASSectionController is defined in AsyncDisplayKit's IGListKit integration headers
        guard let asSectionController = sectionController as? NSObject,
              asSectionController.responds(to: NSSelectorFromString("nodeBlockForItemAtIndex:")) else {
            return {
                let node = ASCellNode()
                node.style.preferredSize = CGSize(width: 50, height: 50)
                return node
            }
        }

        // Call nodeBlockForItemAtIndex: on the section controller
        // This returns an ASCellNodeBlock that we can return
        let selector = NSSelectorFromString("nodeBlockForItemAtIndex:")
        let method = asSectionController.method(for: selector)
        typealias NodeBlockFunction = @convention(c) (NSObject, Selector, Int) -> ASCellNodeBlock
        let nodeBlockFunc = unsafeBitCast(method, to: NodeBlockFunction.self)
        return nodeBlockFunc(asSectionController, selector, indexPath.item)
    }

    func collectionNode(_ collectionNode: ASCollectionNode, nodeForItemAt indexPath: IndexPath) -> ASCellNode {
        guard let sectionController = sectionController(forSection: indexPath.section) else {
            let node = ASCellNode()
            node.style.preferredSize = CGSize(width: 50, height: 50)
            return node
        }

        // Check if section controller responds to nodeForItemAtIndex:
        guard let asSectionController = sectionController as? NSObject,
              asSectionController.responds(to: NSSelectorFromString("nodeForItemAtIndex:")) else {
            let node = ASCellNode()
            node.style.preferredSize = CGSize(width: 50, height: 50)
            return node
        }

        let selector = NSSelectorFromString("nodeForItemAtIndex:")
        let method = asSectionController.method(for: selector)
        typealias NodeFunction = @convention(c) (NSObject, Selector, Int) -> ASCellNode
        let nodeFunc = unsafeBitCast(method, to: NodeFunction.self)
        return nodeFunc(asSectionController, selector, indexPath.item)
    }

    func collectionNode(_ collectionNode: ASCollectionNode, constrainedSizeForItemAt indexPath: IndexPath) -> ASSizeRange {
        guard let sectionController = sectionController(forSection: indexPath.section) else {
            return ASSizeRangeUnconstrained
        }

        // Check if section controller responds to sizeRangeForItemAtIndex:
        guard let asSectionController = sectionController as? NSObject,
              asSectionController.responds(to: NSSelectorFromString("sizeRangeForItemAtIndex:")) else {
            return ASSizeRangeUnconstrained
        }

        let selector = NSSelectorFromString("sizeRangeForItemAtIndex:")
        let method = asSectionController.method(for: selector)
        typealias SizeRangeFunction = @convention(c) (NSObject, Selector, Int) -> ASSizeRange
        let sizeRangeFunc = unsafeBitCast(method, to: SizeRangeFunction.self)
        return sizeRangeFunc(asSectionController, selector, indexPath.item)
    }

    // MARK: - ASCollectionDataSource (Supplementary Elements)

    func collectionNode(_ collectionNode: ASCollectionNode,
                        nodeBlockForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> ASCellNodeBlock {
        let selector = NSSelectorFromString("nodeBlockForSupplementaryElementOfKind:atIndex:")
        guard let source = supplementarySource(forSection: indexPath.section),
              source.responds(to: selector) else {
            return { ASCellNode() }
        }
        let method = source.method(for: selector)
        typealias Fn = @convention(c) (NSObject, Selector, NSString, Int) -> ASCellNodeBlock
        let fn = unsafeBitCast(method, to: Fn.self)
        return fn(source, selector, kind as NSString, indexPath.item)
    }

    func collectionNode(_ collectionNode: ASCollectionNode,
                        nodeForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> ASCellNode {
        let selector = NSSelectorFromString("nodeForSupplementaryElementOfKind:atIndex:")
        guard let source = supplementarySource(forSection: indexPath.section),
              source.responds(to: selector) else {
            return ASCellNode()
        }
        let method = source.method(for: selector)
        typealias Fn = @convention(c) (NSObject, Selector, NSString, Int) -> ASCellNode
        let fn = unsafeBitCast(method, to: Fn.self)
        return fn(source, selector, kind as NSString, indexPath.item)
    }

    func collectionNode(_ collectionNode: ASCollectionNode,
                        supplementaryElementKindsInSection section: Int) -> [String] {
        let selector = NSSelectorFromString("supportedElementKinds")
        guard let source = supplementarySource(forSection: section),
              source.responds(to: selector) else {
            return []
        }
        let method = source.method(for: selector)
        typealias Fn = @convention(c) (NSObject, Selector) -> NSArray
        let fn = unsafeBitCast(method, to: Fn.self)
        return (fn(source, selector) as? [String]) ?? []
    }

    // MARK: - ASCollectionDelegate

    func collectionNode(_ collectionNode: ASCollectionNode, didSelectItemAt indexPath: IndexPath) {
        guard let delegate = delegate else { return }
        let collectionView = collectionNode.view as! UICollectionView
        delegate.collectionView?(collectionView, didSelectItemAt: indexPath)
    }

    func collectionNode(_ collectionNode: ASCollectionNode, didDeselectItemAt indexPath: IndexPath) {
        guard let delegate = delegate else { return }
        let collectionView = collectionNode.view as! UICollectionView
        delegate.collectionView?(collectionView, didDeselectItemAt: indexPath)
    }

    func collectionNode(_ collectionNode: ASCollectionNode, didHighlightItemAt indexPath: IndexPath) {
        guard let delegate = delegate else { return }
        let collectionView = collectionNode.view as! UICollectionView
        delegate.collectionView?(collectionView, didHighlightItemAt: indexPath)
    }

    func collectionNode(_ collectionNode: ASCollectionNode, didUnhighlightItemAt indexPath: IndexPath) {
        guard let delegate = delegate else { return }
        let collectionView = collectionNode.view as! UICollectionView
        delegate.collectionView?(collectionView, didUnhighlightItemAt: indexPath)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        delegate?.scrollViewDidScroll?(scrollView)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.scrollViewWillBeginDragging?(scrollView)
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        delegate?.scrollViewWillEndDragging?(scrollView, withVelocity: velocity, targetContentOffset: targetContentOffset)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        delegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        delegate?.scrollViewDidEndDecelerating?(scrollView)
    }

    func collectionNode(_ collectionNode: ASCollectionNode, willDisplayItemWith node: ASCellNode) {
        guard let delegate = delegate,
              let indexPath = collectionNode.view.indexPath(for: node),
              let contentView = node.view.superview,
              let cell = contentView.superview as? UICollectionViewCell else {
            return
        }
        delegate.collectionView?(collectionNode.view as! UICollectionView, willDisplay: cell, forItemAt: indexPath)
    }

    func collectionNode(_ collectionNode: ASCollectionNode, didEndDisplayingItemWith node: ASCellNode) {
        guard let delegate = delegate,
              let indexPath = collectionNode.view.indexPath(for: node),
              let contentView = node.view.superview,
              let cell = contentView.superview as? UICollectionViewCell else {
            return
        }
        delegate.collectionView?(collectionNode.view as! UICollectionView, didEndDisplaying: cell, forItemAt: indexPath)
    }

    // MARK: - ASCollectionDelegate (Batch Fetching)

    /// Asks whether AsyncDisplayKit should trigger a tail-load batch fetch.
    ///
    /// Forwarding rules mirror `-shouldBatchFetchForCollectionNode:` in the original
    /// Obj-C bridge:
    /// 1. If the upstream `collectionDelegate` (passed to `setCollectionNode`)
    ///    implements the selector itself, delegate to it.
    /// 2. Otherwise, locate the last section's controller and ask it via
    ///    `ASSectionController` (`-shouldBatchFetch` or, if absent, just the presence
    ///    of `-beginBatchFetchWithContext:`).
    /// 3. Capture the chosen section controller in
    ///    `sectionControllerForBatchFetching` so the subsequent
    ///    `willBeginBatchFetchWithContext:` call lands on the same instance.
    func shouldBatchFetch(for collectionNode: ASCollectionNode) -> Bool {
        let delegateSelector = NSSelectorFromString("shouldBatchFetchForCollectionNode:")
        if let asDelegate = collectionDelegate as? NSObject,
           asDelegate.responds(to: delegateSelector) {
            let method = asDelegate.method(for: delegateSelector)
            typealias Fn = @convention(c) (NSObject, Selector, ASCollectionNode) -> Bool
            let fn = unsafeBitCast(method, to: Fn.self)
            return fn(asDelegate, delegateSelector, collectionNode)
        }

        let sectionCount = numberOfSections(in: collectionNode)
        guard sectionCount > 0,
              let controller = sectionController(forSection: sectionCount - 1) as? NSObject else {
            return false
        }

        let shouldBatchFetchSel = NSSelectorFromString("shouldBatchFetch")
        let beginBatchFetchSel = NSSelectorFromString("beginBatchFetchWithContext:")

        let result: Bool
        if controller.responds(to: shouldBatchFetchSel) {
            let method = controller.method(for: shouldBatchFetchSel)
            typealias Fn = @convention(c) (NSObject, Selector) -> Bool
            let fn = unsafeBitCast(method, to: Fn.self)
            result = fn(controller, shouldBatchFetchSel)
        } else {
            result = controller.responds(to: beginBatchFetchSel)
        }

        if result {
            sectionControllerForBatchFetching = controller as? ListSectionController
        }
        return result
    }

    /// Called by AsyncDisplayKit on a background queue when it's time to fetch more
    /// content. Forwards to the upstream collection delegate if it implements the
    /// selector, otherwise dispatches to the section controller captured in
    /// `shouldBatchFetch(for:)`.
    func collectionNode(_ collectionNode: ASCollectionNode,
                        willBeginBatchFetchWith context: ASBatchContext) {
        let delegateSelector = NSSelectorFromString("collectionNode:willBeginBatchFetchWithContext:")
        if let asDelegate = collectionDelegate as? NSObject,
           asDelegate.responds(to: delegateSelector) {
            let method = asDelegate.method(for: delegateSelector)
            typealias Fn = @convention(c) (NSObject, Selector, ASCollectionNode, ASBatchContext) -> Void
            let fn = unsafeBitCast(method, to: Fn.self)
            fn(asDelegate, delegateSelector, collectionNode, context)
            return
        }

        guard let controller = sectionControllerForBatchFetching as? NSObject else { return }
        sectionControllerForBatchFetching = nil

        let selector = NSSelectorFromString("beginBatchFetchWithContext:")
        guard controller.responds(to: selector) else { return }
        let method = controller.method(for: selector)
        typealias Fn = @convention(c) (NSObject, Selector, ASBatchContext) -> Void
        let fn = unsafeBitCast(method, to: Fn.self)
        fn(controller, selector, context)
    }

    // MARK: - ASCollectionDelegateFlowLayout (Headers/Footers)

    /// AsyncDisplayKit-side header sizing. Returns `ASSizeRangeZero` when the
    /// supplementary source either doesn't exist or doesn't implement
    /// `-sizeRangeForSupplementaryElementOfKind:atIndex:`, matching the original
    /// Obj-C bridge behavior (no header).
    func collectionNode(_ collectionNode: ASCollectionNode,
                        sizeRangeForHeaderInSection section: Int) -> ASSizeRange {
        return sizeRangeForSupplementaryElement(ofKind: UICollectionView.elementKindSectionHeader,
                                                in: section)
    }

    func collectionNode(_ collectionNode: ASCollectionNode,
                        sizeRangeForFooterInSection section: Int) -> ASSizeRange {
        return sizeRangeForSupplementaryElement(ofKind: UICollectionView.elementKindSectionFooter,
                                                in: section)
    }

    private func sizeRangeForSupplementaryElement(ofKind kind: String, in section: Int) -> ASSizeRange {
        let selector = NSSelectorFromString("sizeRangeForSupplementaryElementOfKind:atIndex:")
        guard let source = supplementarySource(forSection: section),
              source.responds(to: selector) else {
            return ASSizeRangeZero
        }
        let method = source.method(for: selector)
        typealias Fn = @convention(c) (NSObject, Selector, NSString, Int) -> ASSizeRange
        let fn = unsafeBitCast(method, to: Fn.self)
        return fn(source, selector, kind as NSString, 0)
    }

    // MARK: - ASCollectionDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return delegate?.collectionView?(collectionView, layout: collectionViewLayout, insetForSectionAt: section) ?? .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return delegate?.collectionView?(collectionView, layout: collectionViewLayout, minimumLineSpacingForSectionAt: section) ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return delegate?.collectionView?(collectionView, layout: collectionViewLayout, minimumInteritemSpacingForSectionAt: section) ?? 0
    }

    // MARK: - ASCollectionDataSourceInterop

    /// Required by `ASCollectionDataSourceInterop` (runtime-declared above in
    /// `conforms(to:)`). AsyncDisplayKit relies on these forwarders to bridge
    /// `IGListAdapter`'s UIKit data-source path to ASCollectionNode's interop layer.
    ///
    /// The explicit `@objc(...)` selectors are critical: AsyncDisplayKit calls
    /// these methods with the historical UIKit selector names (e.g.
    /// `collectionView:cellForItemAtIndexPath:`, with the `IndexPath` suffix).
    /// Swift's automatic `@objc` name generation derives the selector from the
    /// Swift argument labels, producing `collectionView:cellForItemAt:`, which
    /// the Obj-C runtime does not recognize. Without the explicit names, ASCollectionView
    /// hits `_CF_forwarding_prep_0` → "unrecognized selector sent to instance"
    /// on the very first cell dequeue.
    @objc(collectionView:cellForItemAtIndexPath:)
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Guard against stale layout attributes: when IGListKit falls back to
        // `[UICollectionView reloadData]` after detecting a section-count mismatch in
        // `IGListBatchUpdateTransaction._didDiff:onBackground:`, the surrounding
        // `layoutBelowIfNeeded` pass continues to request cells based on the
        // collection view's already-cached layout attributes — which still reference
        // sections that no longer exist in the adapter's section map. `IGListAdapter`
        // asserts at `IGListAdapter+UICollectionView.m:47` ("Section controller is
        // nil { … sectionController: (null), dataSource: <…> }") when forwarded a
        // `cellForItemAtIndexPath:` for such a stale section. Check section
        // controller validity here before forwarding to IGListAdapter; if the
        // section has been removed from the adapter's map, return a placeholder
        // cell so the assertion is sidestepped and the next valid layout pass
        // discards the placeholder.
        guard let dataSource = dataSource,
              sectionController(forSection: indexPath.section) != nil else {
            return UICollectionViewCell()
        }
        return dataSource.collectionView(collectionView, cellForItemAt: indexPath)
    }

    @objc(collectionView:viewForSupplementaryElementOfKind:atIndexPath:)
    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        // Guard against stale layout attributes: after performUpdates reduces the
        // section count, UICollectionView may still request supplementary views for
        // sections that no longer exist in the adapter's section map. IGListAdapter
        // throws NSInternalInconsistencyException in that case, so check validity
        // here before forwarding.
        guard let dataSource = dataSource,
              sectionController(forSection: indexPath.section) != nil,
              let view = dataSource.collectionView?(collectionView,
                                                   viewForSupplementaryElementOfKind: kind,
                                                   at: indexPath) else {
            return UICollectionReusableView()
        }
        return view
    }

    // MARK: - ASCollectionDelegateInterop

    @objc(collectionView:willDisplayCell:forItemAtIndexPath:)
    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        delegate?.collectionView?(collectionView, willDisplay: cell, forItemAt: indexPath)
    }

    @objc(collectionView:didEndDisplayingCell:forItemAtIndexPath:)
    func collectionView(_ collectionView: UICollectionView,
                        didEndDisplaying cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        delegate?.collectionView?(collectionView, didEndDisplaying: cell, forItemAt: indexPath)
    }
}

// MARK: - Supplementary View Source Methods

/// Pure Swift implementation of ASIGListSupplementaryViewSourceMethods for SPM builds.
///
/// ## Purpose
///
/// This enum provides static helper methods for IGListKit section controllers that need to
/// display supplementary views (headers/footers) when using AsyncDisplayKit with SPM.
///
/// ## Why This Exists
///
/// The original Objective-C class `ASIGListSupplementaryViewSourceMethods` is wrapped in
/// `#if AS_IG_LIST_KIT` directives, which prevents it from being accessible in Swift when
/// using SPM (even with traits enabled). This is a Swift reimplementation of that functionality.
///
/// ## Reference Implementation
///
/// Based on the Objective-C implementation in:
/// - `Source/AsyncDisplayKit+IGListKitMethods.mm` (lines 36-51)
/// - Used in examples like `examples/ASDKgram/Sample/PhotoFeedSectionController.m` (lines 134-142)
///
/// ## Usage
///
/// Your section controller should:
/// 1. Conform to both `ListSupplementaryViewSource` (IGListKit) and `ASSupplementaryNodeSource` (AsyncDisplayKit)
/// 2. Use these methods in the required `IGListSupplementaryViewSource` protocol methods
/// 3. Implement the `ASSupplementaryNodeSource` protocol methods to provide nodes
///
/// ### Example
///
/// ```swift
/// class MySectionController: ListSectionController, ListSupplementaryViewSource {
///
///     // MARK: - ListSupplementaryViewSource (IGListKit protocol)
///
///     func supportedElementKinds() -> [String] {
///         return [UICollectionView.elementKindSectionHeader]
///     }
///
///     func viewForSupplementaryElement(
///         ofKind elementKind: String,
///         at index: Int
///     ) -> UICollectionReusableView {
///         // Delegate to helper method
///         return SupplementaryViewSourceMethods.viewForSupplementaryElement(
///             ofKind: elementKind,
///             at: index,
///             sectionController: self
///         )
///     }
///
///     func sizeForSupplementaryView(
///         ofKind elementKind: String,
///         at index: Int
///     ) -> CGSize {
///         // Delegate to helper method
///         return SupplementaryViewSourceMethods.sizeForSupplementaryView(
///             ofKind: elementKind,
///             at: index
///         )
///     }
/// }
///
/// // MARK: - ASSupplementaryNodeSource (AsyncDisplayKit protocol)
///
/// extension MySectionController: ASSupplementaryNodeSource {
///
///     func nodeBlockForSupplementaryElement(
///         ofKind elementKind: String,
///         at index: Int
///     ) -> ASCellNodeBlock {
///         return {
///             let node = HeaderNode()
///             // Configure node...
///             return node
///         }
///     }
///
///     func sizeRangeForSupplementaryElement(
///         ofKind elementKind: String,
///         at index: Int
///     ) -> ASSizeRange {
///         return ASSizeRange(
///             min: CGSize(width: 0, height: 44),
///             max: CGSize(width: CGFloat.infinity, height: 44)
///         )
///     }
/// }
/// ```
///
/// ## Thread Safety
///
/// These methods are safe to call from any thread, as they delegate to IGListKit's
/// thread-safe `ListCollectionContext` methods.
///
/// ## See Also
///
/// - `ASSupplementaryNodeSource` protocol for the AsyncDisplayKit side of supplementary views
/// - `ListSupplementaryViewSource` protocol for the IGListKit side
/// - Original Objective-C: `ASIGListSupplementaryViewSourceMethods` in `AsyncDisplayKit+IGListKitMethods.h`
public enum SupplementaryViewSourceMethods {

    /// Dequeues a reusable supplementary view for AsyncDisplayKit.
    ///
    /// This method should be called from your section controller's
    /// `viewForSupplementaryElement(ofKind:at:)` method.
    ///
    /// ## How It Works
    ///
    /// This method asks IGListKit's collection context to dequeue a special
    /// `_ASCollectionReusableView` that wraps an `ASCellNode`. AsyncDisplayKit
    /// handles the node → view wrapping internally.
    ///
    /// ## Implementation Note
    ///
    /// Equivalent to calling:
    /// ```objc
    /// [sectionController.collectionContext
    ///     dequeueReusableSupplementaryViewOfKind:elementKind
    ///     forSectionController:sectionController
    ///     class:[_ASCollectionReusableView class]
    ///     atIndex:index];
    /// ```
    ///
    /// - Parameters:
    ///   - elementKind: The kind of supplementary element (e.g., `UICollectionView.elementKindSectionHeader`)
    ///   - index: The index of the supplementary element
    ///   - sectionController: The section controller requesting the view
    ///
    /// - Returns: A dequeued `UICollectionReusableView` that wraps an `ASCellNode`
    ///
    /// - Warning: Your section controller MUST conform to `ASSupplementaryNodeSource`
    ///            and implement `nodeBlockForSupplementaryElement(ofKind:at:)` or
    ///            `nodeForSupplementaryElement(ofKind:at:)` for this to work.
    @MainActor
    public static func viewForSupplementaryElement(
        ofKind elementKind: String,
        at index: Int,
        sectionController: ListSectionController
    ) -> UICollectionReusableView {
        guard let collectionContext = sectionController.collectionContext else {
            assertionFailure("Collection context is nil. Has the section controller been added to an adapter?")
            return UICollectionReusableView()
        }

        // Get the _ASCollectionReusableView class dynamically
        // This class is internal to AsyncDisplayKit and wraps ASCellNode in a UICollectionReusableView
        guard let reusableViewClass = NSClassFromString("_ASCollectionReusableView") else {
            assertionFailure("Could not find _ASCollectionReusableView class. Is AsyncDisplayKit properly linked?")
            return UICollectionReusableView()
        }

        // Dequeue using IGListKit's context
        // The context knows to call our ASSupplementaryNodeSource methods
        let view = collectionContext.dequeueReusableSupplementaryView(
            ofKind: elementKind,
            for: sectionController,
            class: reusableViewClass as! UICollectionReusableView.Type,
            at: index
        )

        return view
    }

    /// Returns a size for supplementary views (always returns `.zero`).
    ///
    /// This method should be called from your section controller's
    /// `sizeForSupplementaryView(ofKind:at:)` method.
    ///
    /// ## Why This Returns Zero
    ///
    /// AsyncDisplayKit uses its own sizing system based on `ASSizeRange` (via the
    /// `sizeRangeForSupplementaryElement(ofKind:at:)` method in `ASSupplementaryNodeSource`).
    /// The UIKit-based size returned here is ignored by AsyncDisplayKit's layout engine.
    ///
    /// Returning `.zero` here is intentional and matches the Objective-C implementation,
    /// which triggers an assertion in debug builds if this method is unexpectedly called.
    ///
    /// ## Implementation Note
    ///
    /// Equivalent to:
    /// ```objc
    /// + (CGSize)sizeForSupplementaryViewOfKind:(NSString *)elementKind atIndex:(NSInteger)index {
    ///     ASDisplayNodeFailAssert(@"Did not expect %@ to be called.", NSStringFromSelector(_cmd));
    ///     return CGSizeZero;
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - elementKind: The kind of supplementary element (unused)
    ///   - index: The index of the supplementary element (unused)
    ///
    /// - Returns: Always returns `CGSize.zero`
    ///
    /// - Note: Your section controller should implement
    ///         `sizeRangeForSupplementaryElement(ofKind:at:)` from
    ///         `ASSupplementaryNodeSource` to control supplementary view sizing.
    public static func sizeForSupplementaryView(
        ofKind elementKind: String,
        at index: Int
    ) -> CGSize {
        // This matches the Objective-C implementation which triggers ASDisplayNodeFailAssert
        // We don't assert here because Swift doesn't have the same ASDisplayNodeFailAssert macro
        // but we document that this should not be called and return zero
        return .zero
    }
}

// MARK: - Section Controller Methods

/// Pure Swift implementation of ASIGListSectionControllerMethods for SPM builds.
///
/// Provides helper methods for IGListKit section controllers using AsyncDisplayKit.
/// Equivalent to the Objective-C `ASIGListSectionControllerMethods` class.
public enum SectionControllerMethods {

    /// Dequeues a reusable cell for AsyncDisplayKit.
    ///
    /// Call this from your section controller's `cellForItem(at:)` method.
    /// AsyncDisplayKit manages actual cell rendering via `nodeBlockForItem(at:)`.
    ///
    /// - Parameters:
    ///   - index: The index of the item
    ///   - sectionController: The section controller requesting the cell
    ///
    /// - Returns: A dequeued `UICollectionViewCell` wrapping an `ASCellNode`
    @MainActor
    public static func cellForItem(
        at index: Int,
        sectionController: ListSectionController
    ) -> UICollectionViewCell {
        guard let collectionContext = sectionController.collectionContext else {
            assertionFailure("Collection context is nil. Has the section controller been added to an adapter?")
            return UICollectionViewCell()
        }

        guard let cellClass = NSClassFromString("_ASCollectionViewCell") else {
            assertionFailure("Could not find _ASCollectionViewCell class. Is AsyncDisplayKit properly linked?")
            return UICollectionViewCell()
        }

        return collectionContext.dequeueReusableCell(
            of: cellClass as! UICollectionViewCell.Type,
            for: sectionController,
            at: index
        )
    }

    /// Returns `.zero` — AsyncDisplayKit handles sizing via `sizeRangeForItem(at:)`.
    ///
    /// Call this from your section controller's `sizeForItem(at:)` method.
    public static func sizeForItem(at index: Int) -> CGSize {
        return .zero
    }
}

// MARK: - List Adapter Extension

/// Swift extensions for IGListKit integration with Texture
extension ListAdapter {

    // Static key for associated object storage (analogous to _cmd in Objective-C)
    private static var dataSourceKey: UInt8 = 0

    /// Sets an ASCollectionNode as the collection view for this adapter.
    ///
    /// This method connects an ASCollectionNode to the IGListKit adapter by setting up
    /// the appropriate data source bridging. This is a pure Swift implementation that
    /// provides the same functionality as the Objective-C `setASDKCollectionNode:` method.
    ///
    /// - Parameter collectionNode: The ASCollectionNode to use with this adapter
    ///
    /// - Note: This method can only be called once per adapter and must be called on the main thread.
    @MainActor
    public func setCollectionNode(_ collectionNode: ASCollectionNode) {
        // Use associated objects to store data source
        let key = UnsafeRawPointer(&ListAdapter.dataSourceKey)

        if objc_getAssociatedObject(self, key) != nil {
            assertionFailure("Attempt to call setCollectionNode multiple times on the same list adapter. Not currently allowed!")
            return
        }

        let dataSource = IGListAdapterDataSourceBridge(listAdapter: self, collectionDelegate: collectionNode.delegate)
        objc_setAssociatedObject(self, key, dataSource, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        collectionNode.dataSource = dataSource
        collectionNode.delegate = dataSource

        if collectionNode.isNodeLoaded {
            self.collectionView = collectionNode.view as? UICollectionView
        } else {
            collectionNode.onDidLoad { [weak self] node in
                self?.collectionView = node.view as? UICollectionView
            }
        }
    }

    /// Performs `performUpdates(animated:completion:)` after a pre-flight check that the
    /// collection view's section count matches the adapter's last applied object count.
    /// If the counts diverge, falls back to `reloadData(completion:)` instead of letting
    /// IGListKit raise `NSInternalInconsistencyException` from
    /// `IGListBatchUpdateTransaction._didDiff:onBackground:` with the message
    ///
    ///     The UICollectionView's section count (N) didn't match the
    ///     IGListAdapter's count (M), so we can't performBatchUpdates.
    ///     Falling back to reloadData.
    ///
    /// (IGListKit's own message text says "falling back to reloadData", but `IGAssert`
    /// raises an NSException in release builds — the documented fallback never executes.)
    ///
    /// ## When this guard catches the mismatch
    ///
    /// The pre-flight catches **already-divergent** states: the collection view was reset
    /// externally (e.g. `reloadData` called from another code path, the data source was
    /// reassigned, the view was re-laid out and lost its section count) while the adapter
    /// still holds the previous applied snapshot.
    ///
    /// ## When this guard does NOT catch the mismatch
    ///
    /// It does **not** prevent the same exception when the divergence is produced by a
    /// concurrent in-flight diff. IGListKit captures a `sectionMap` snapshot inside its
    /// background diff queue; a second `performUpdates` that mutates the data source
    /// between snapshot and apply will still raise from `_didDiff:onBackground:` —
    /// the assertion fires inside IGListKit, after this guard has already returned.
    /// To prevent that race, the caller must serialize concurrent loads on the same
    /// adapter (cancel the in-flight task before kicking off a new one).
    ///
    /// Use this in tandem with a serialization strategy, not as a replacement for one.
    ///
    /// - Parameters:
    ///   - animated: Forwarded to `performUpdates` when the pre-flight check passes.
    ///     Ignored on the `reloadData` fallback path — `reloadData` is never animated.
    ///   - completion: Invoked when either `performUpdates` or `reloadData` finishes.
    ///     The `Bool` argument matches `performUpdates` semantics on the normal path.
    ///     On the `reloadData` fallback path the value is always `true`, since
    ///     `reloadData` has no concept of a partial result.
    @MainActor
    public func performUpdatesWithFallback(animated: Bool,
                                   completion: ((Bool) -> Void)? = nil) {
        guard let view = collectionView else {
            performUpdates(animated: animated, completion: completion)
            return
        }

        let viewSections = view.numberOfSections
        let adapterSections = objects().count

        if viewSections != adapterSections {
            os_log(.error, log: iglistkitGuardLog,
                   "performUpdatesWithFallback: section-count divergence (view=%{public}d, adapter=%{public}d) — falling back to reloadData",
                   viewSections, adapterSections)
            reloadData { _ in
                completion?(true)
            }
            return
        }

        performUpdates(animated: animated, completion: completion)
    }

    /// `async` overload of `performUpdatesWithFallback(animated:completion:)`.
    /// Suspends until the underlying `performUpdates` or `reloadData` fallback finishes,
    /// matching the `await adapter.performUpdates(animated:)` call shape that the
    /// completion-handler bridge produces for `performUpdates`.
    @MainActor
    @discardableResult
    public func performUpdatesWithFallback(animated: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            performUpdatesWithFallback(animated: animated) { finished in
                continuation.resume(returning: finished)
            }
        }
    }
}
