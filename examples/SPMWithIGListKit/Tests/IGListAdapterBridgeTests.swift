import AsyncDisplayKit
import IGListKit
import Testing
import TextureIGListKitExtensions
@testable import SPMWithIGListKit
import UIKit

/// Regression tests for the runtime-conformed `ASCollectionDataSourceInterop` /
/// `ASCollectionDelegateInterop` surface that `IGListAdapterDataSourceBridge`
/// implements on top of `IGListAdapter.setCollectionNode(_:)`.
///
/// Because the Interop protocols are declared via the runtime
/// `conforms(to:)` override (not via compile-time protocol conformance on the
/// Swift class), the Swift compiler's protocol method imap does not reach
/// those methods and Obj-C selectors are derived purely from Swift argument
/// labels. Without an explicit `@objc(<historical-selector>)` annotation the
/// generated selectors lose the trailing `IndexPath` suffix that
/// AsyncDisplayKit / UIKit call with, and the first dispatch goes through
/// `_CF_forwarding_prep_0` -> `unrecognized selector sent to instance`.
///
/// The first two tests exercise the bridge end-to-end through `performUpdates`
/// (the same call path real consumers take after data arrives). The third
/// queries the Obj-C runtime directly so that scroll-only and supplementary
/// selectors — which a unit test cannot reliably trigger via UI lifecycle —
/// are still covered.
@Suite("IGListAdapterDataSourceBridge Regression")
@MainActor
struct IGListAdapterBridgeTests {

    /// Drives `ASCollectionView.collectionView:cellForItemAtIndexPath:` through
    /// the bridge's `ASCollectionDataSourceInterop` forwarder. Mirrors the
    /// production lifecycle: empty data source at wire-up, view loads, data
    /// arrives, performUpdates applies the first diff.
    @Test("setCollectionNode dequeues cells through interop bridge")
    func setCollectionNode_dequeuesCells_throughInteropBridge() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        let viewController = UIViewController()
        window.rootViewController = viewController
        window.makeKeyAndVisible()

        let collectionNode = ASCollectionNode(collectionViewLayout: UICollectionViewFlowLayout())
        collectionNode.frame = window.bounds
        viewController.view.addSubnode(collectionNode)
        // Force the ASCollectionNode to load its UICollectionView synchronously.
        // In a hosted view controller this happens during the standard
        // viewWillAppear -> layoutSubviews pass, but a unit test does not run
        // that lifecycle; without an explicit load the onDidLoad callback that
        // `setCollectionNode` registers fires after our explicit
        // `performUpdates` call and leaves the adapter and the collection view
        // out of sync.
        _ = collectionNode.view

        let adapter = ListAdapter(updater: ListAdapterUpdater(),
                                  viewController: viewController,
                                  workingRangeSize: 0)
        let dataSource = TestListAdapterDataSource(items: [])
        adapter.dataSource = dataSource
        adapter.setCollectionNode(collectionNode)

        // Data arrives, then performUpdates(animated:) is called. On the first
        // batch update IGListKit asks the bridge for
        // `collectionView:cellForItemAtIndexPath:`. A Swift-renaming regression
        // on that selector terminates the process here.
        dataSource.items = [TestItem(id: 1), TestItem(id: 2)]
        await withCheckedContinuation { continuation in
            adapter.performUpdates(animated: false) { _ in
                continuation.resume()
            }
        }
        collectionNode.view.layoutIfNeeded()

        #expect(collectionNode.view.numberOfSections == 2)
        #expect(collectionNode.view.numberOfItems(inSection: 0) == 1)
        #expect(collectionNode.view.cellForItem(at: IndexPath(item: 0, section: 0)) != nil)
    }

    /// Runs two consecutive `performUpdates(animated:)` passes — the diff
    /// sequence a consumer hits when a refresh follows the initial fetch.
    /// Exercises `numberOfSectionsInCollectionNode:` forwarding during apply.
    @Test("performUpdates applies consecutive diffs without crashing")
    func performUpdates_appliesConsecutiveDiffs_withoutCrash() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        let viewController = UIViewController()
        window.rootViewController = viewController
        window.makeKeyAndVisible()

        let collectionNode = ASCollectionNode(collectionViewLayout: UICollectionViewFlowLayout())
        collectionNode.frame = window.bounds
        viewController.view.addSubnode(collectionNode)
        _ = collectionNode.view

        let adapter = ListAdapter(updater: ListAdapterUpdater(),
                                  viewController: viewController,
                                  workingRangeSize: 0)
        let dataSource = TestListAdapterDataSource(items: [])
        adapter.dataSource = dataSource
        adapter.setCollectionNode(collectionNode)

        // First fetch: 0 -> 1 section.
        dataSource.items = [TestItem(id: 1)]
        await withCheckedContinuation { continuation in
            adapter.performUpdates(animated: false) { _ in
                continuation.resume()
            }
        }
        collectionNode.view.layoutIfNeeded()
        #expect(collectionNode.view.numberOfSections == 1)

        // Subsequent update (refresh / push): 1 -> 3.
        dataSource.items = [TestItem(id: 1), TestItem(id: 2), TestItem(id: 3)]
        await withCheckedContinuation { continuation in
            adapter.performUpdates(animated: false) { _ in
                continuation.resume()
            }
        }

        #expect(collectionNode.view.numberOfSections == 3)
    }

    /// Direct selector-conformance probe. `willDisplayCell:`,
    /// `didEndDisplayingCell:` and `viewForSupplementaryElementOfKind:atIndexPath:`
    /// only fire under scroll or header layout, which a unit test cannot
    /// reliably trigger. This test asks the Obj-C runtime whether the bridge
    /// responds to each historical selector that AsyncDisplayKit / UIKit
    /// dispatch through the runtime, so a Swift-renaming regression on the
    /// runtime-conformed Interop protocols fails in milliseconds with no UI
    /// plumbing.
    @Test("Bridge responds to all historical interop selectors")
    func bridge_responds_to_all_historical_interop_selectors() {
        let collectionNode = ASCollectionNode(collectionViewLayout: UICollectionViewFlowLayout())
        collectionNode.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        _ = collectionNode.view

        let adapter = ListAdapter(updater: ListAdapterUpdater(),
                                  viewController: nil,
                                  workingRangeSize: 0)
        let dataSource = TestListAdapterDataSource(items: [TestItem(id: 1)])
        adapter.dataSource = dataSource
        adapter.setCollectionNode(collectionNode)

        let bridge = collectionNode.dataSource

        let instanceSelectors = ["collectionView:cellForItemAtIndexPath:",
                                 "collectionView:viewForSupplementaryElementOfKind:atIndexPath:",
                                 "collectionView:willDisplayCell:forItemAtIndexPath:",
                                 "collectionView:didEndDisplayingCell:forItemAtIndexPath:"]
        for name in instanceSelectors {
            let selector = NSSelectorFromString(name)
            #expect(bridge?.responds(to: selector) == true,
                    "Bridge missing instance selector \(name)")
        }

        let classMethodSelector = NSSelectorFromString("dequeuesCellsForNodeBackedItems")
        let bridgeClass: AnyClass? = bridge.map { object_getClass($0) } ?? nil
        #expect(bridgeClass?.responds(to: classMethodSelector) == true,
                "Bridge class missing +dequeuesCellsForNodeBackedItems")
    }

    /// Probes the actual return value of `+dequeuesCellsForNodeBackedItems`,
    /// not just its existence. The class contract of
    /// `ASCollectionDataSourceInterop` requires this to be `true` so that
    /// `ASCollectionView` routes cell creation through
    /// `IGListAdapter.collectionView:cellForItemAtIndexPath:`. If it ever
    /// returns `false`, ASCollectionView bypasses the adapter's section map
    /// and `willDisplayCell:forItemAtIndexPath:` later fires for indexPaths
    /// the adapter does not know about, producing the
    /// `Invalid parameter not satisfying: sectionController != nil` crash
    /// observed in production at `IGListAdapter.m:897`.
    @Test("Bridge +dequeuesCellsForNodeBackedItems returns true")
    func bridge_dequeuesCellsForNodeBackedItems_returnsTrue() {
        let collectionNode = ASCollectionNode(collectionViewLayout: UICollectionViewFlowLayout())
        _ = collectionNode.view

        let adapter = ListAdapter(updater: ListAdapterUpdater(),
                                  viewController: nil,
                                  workingRangeSize: 0)
        let dataSource = TestListAdapterDataSource(items: [TestItem(id: 1)])
        adapter.dataSource = dataSource
        adapter.setCollectionNode(collectionNode)

        let bridge = collectionNode.dataSource
        let bridgeClass: AnyClass = object_getClass(bridge)!
        let selector = NSSelectorFromString("dequeuesCellsForNodeBackedItems")

        let imp = bridgeClass.method(for: selector)
        typealias Fn = @convention(c) (AnyClass, Selector) -> Bool
        let dequeues = unsafeBitCast(imp, to: Fn.self)(bridgeClass, selector)

        #expect(dequeues == true,
                "+dequeuesCellsForNodeBackedItems must return true; returning false makes ASCollectionView skip IGListAdapter.cellForItemAtIndexPath: and crash with sectionController != nil at IGListAdapter.m:897")
    }

    /// Asserts that `setCollectionNode(_:)` leaves
    /// `ListAdapterUpdater.allowsBackgroundDiffing` set to `false`. When that
    /// flag is `true`, IGListKit snapshots `numberOfSectionsInCollectionView:`
    /// on a background queue and re-reads it on the main thread when
    /// applying the result. `ASCollectionNode`-backed adapters routinely
    /// mutate their object array between those two points, so on apply the
    /// live count does not match the snapshot and IGListKit raises
    /// `NSInternalInconsistencyException` at
    /// `IGListBatchUpdateTransaction.m:145`. The lifecycle tests cannot
    /// trigger that race reliably in a unit-test environment, so this
    /// defensive assertion on the flag itself is the only deterministic
    /// guard.
    @Test("setCollectionNode disables allowsBackgroundDiffing on the updater")
    func setCollectionNode_disablesBackgroundDiffing() {
        let collectionNode = ASCollectionNode(collectionViewLayout: UICollectionViewFlowLayout())
        _ = collectionNode.view

        let adapter = ListAdapter(updater: ListAdapterUpdater(),
                                  viewController: nil,
                                  workingRangeSize: 0)
        let dataSource = TestListAdapterDataSource(items: [TestItem(id: 1)])
        adapter.dataSource = dataSource
        adapter.setCollectionNode(collectionNode)

        let updater = adapter.updater as? ListAdapterUpdater
        #expect(updater?.allowsBackgroundDiffing == false,
                "allowsBackgroundDiffing must be false for ASCollectionNode consumers; with it on, IGListKit races between the background diff snapshot and the main-thread apply and throws at IGListBatchUpdateTransaction.m:145")
    }

    /// After `performUpdates` removes sections, UICollectionView may still hold
    /// cached layout attributes for the removed sections and request supplementary
    /// views for them during a subsequent layout pass. Without a guard, the bridge
    /// forwards to IGListAdapter which throws `NSInternalInconsistencyException`
    /// because the section controller at that index is nil.
    ///
    /// This test calls the bridge's Interop selector directly with an index that
    /// is outside the adapter's current section map — the call must return a
    /// placeholder view without crashing.
    @Test("bridge returns placeholder view for stale supplementary section after removal")
    func bridge_returnsPlaceholder_forStaleSuppViewAfterSectionRemoval() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        let viewController = UIViewController()
        window.rootViewController = viewController
        window.makeKeyAndVisible()

        let collectionNode = ASCollectionNode(collectionViewLayout: UICollectionViewFlowLayout())
        collectionNode.frame = window.bounds
        viewController.view.addSubnode(collectionNode)
        _ = collectionNode.view

        let adapter = ListAdapter(updater: ListAdapterUpdater(),
                                  viewController: viewController,
                                  workingRangeSize: 0)
        let dataSource = HeaderTestDataSource(items: [])
        adapter.dataSource = dataSource
        adapter.setCollectionNode(collectionNode)

        // Load 3 sections so IGListAdapter has a valid section map for [0,1,2].
        dataSource.items = [TestItem(id: 1), TestItem(id: 2), TestItem(id: 3)]
        await withCheckedContinuation { continuation in
            adapter.performUpdates(animated: false) { _ in continuation.resume() }
        }
        collectionNode.view.layoutIfNeeded()
        #expect(collectionNode.view.numberOfSections == 3)

        // Reduce to 1 section. Section map in IGListAdapter now only covers [0].
        // UICollectionView may still hold stale layout attributes for sections 1
        // and 2 until its next full layout invalidation.
        dataSource.items = [TestItem(id: 1)]
        await withCheckedContinuation { continuation in
            adapter.performUpdates(animated: false) { _ in continuation.resume() }
        }
        #expect(collectionNode.view.numberOfSections == 1)

        // Simulate UICollectionView requesting a supplementary view for the now-
        // removed section 2. Without the bridge guard, IGListAdapter would throw
        // NSInternalInconsistencyException here.
        let bridge = collectionNode.dataSource
        guard let bridgeObj = bridge as? NSObject else {
            Issue.record("collectionNode.dataSource is not NSObject — bridge not installed")
            return
        }
        let sel = NSSelectorFromString("collectionView:viewForSupplementaryElementOfKind:atIndexPath:")
        guard bridgeObj.responds(to: sel) else {
            Issue.record("Bridge does not respond to viewForSupplementaryElementOfKind:atIndexPath:")
            return
        }
        let imp = bridgeObj.method(for: sel)
        typealias SupplementaryFn = @convention(c) (NSObject, Selector, UICollectionView, NSString, IndexPath) -> UICollectionReusableView
        let fn = unsafeBitCast(imp, to: SupplementaryFn.self)
        let staleIndexPath = IndexPath(item: 0, section: 2)
        // Must not crash — returns a zero-size placeholder instead of throwing.
        let view = fn(bridgeObj, sel, collectionNode.view,
                      UICollectionView.elementKindSectionHeader as NSString,
                      staleIndexPath)
        #expect(view is UICollectionReusableView,
                "Bridge must return a placeholder view for a stale section, not crash via IGListAdapter")
    }

    /// Exercises the supplementary header layout path on the bridge.
    ///
    /// UICollectionView populates `layoutAttributesForSupplementaryElement`
    /// from the size returned by the `ASCollectionDelegateFlowLayout`
    /// `collectionNode:sizeRangeForHeaderInSection:` forwarder, which in
    /// turn invokes `sizeRangeForSupplementaryElementOfKind:atIndex:` on
    /// the section controller's supplementary source. Breaking either of
    /// those forwarders (e.g. dropping the selector dispatch, returning
    /// `ASSizeRangeZero`) leaves the layout with a nil or zero-height
    /// header.
    ///
    /// Scope: this test catches regressions in the **sizing** forwarders.
    /// The node-block forwarder
    /// (`nodeBlockForSupplementaryElementOfKind:atIndexPath:`) governs the
    /// rendered content of the header, not its layout attributes, so a
    /// regression there is not caught here. Test 3 (selector probe) checks
    /// the runtime-conformed Interop selector
    /// `viewForSupplementaryElementOfKind:atIndexPath:` separately.
    @Test("supplementary header layout flows through the bridge")
    func supplementary_header_layoutFlowsThroughBridge() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        let viewController = UIViewController()
        window.rootViewController = viewController
        window.makeKeyAndVisible()

        let collectionNode = ASCollectionNode(collectionViewLayout: UICollectionViewFlowLayout())
        collectionNode.frame = window.bounds
        viewController.view.addSubnode(collectionNode)
        _ = collectionNode.view

        let adapter = ListAdapter(updater: ListAdapterUpdater(),
                                  viewController: viewController,
                                  workingRangeSize: 0)
        let dataSource = HeaderTestDataSource(items: [])
        adapter.dataSource = dataSource
        adapter.setCollectionNode(collectionNode)

        dataSource.items = [TestItem(id: 1)]
        await withCheckedContinuation { continuation in
            adapter.performUpdates(animated: false) { _ in
                continuation.resume()
            }
        }
        collectionNode.view.layoutIfNeeded()

        #expect(collectionNode.view.numberOfSections == 1)
        let headerAttributes = collectionNode.view.layoutAttributesForSupplementaryElement(
            ofKind: UICollectionView.elementKindSectionHeader,
            at: IndexPath(item: 0, section: 0)
        )
        #expect(headerAttributes != nil,
                "Bridge did not produce supplementary header layout attributes; the supplementary-view forwarders on the bridge are unreachable from ASCollectionNode")
        #expect(headerAttributes?.size.height ?? 0 > 0,
                "Header layout reported zero height; sizeRangeForHeaderInSection: forwarder is not returning the section controller's size")
    }

    /// Pre-flight guard in `performUpdatesWithFallback` must let normal diffs flow through:
    /// when `collectionView.numberOfSections` already matches
    /// `adapter.objects().count`, the call must dispatch to `performUpdates(animated:)`
    /// and apply the diff exactly as a direct call to `performUpdates(animated:)` would.
    /// This is the common case — the guard must not regress it.
    @Test("performUpdatesWithFallback applies diffs when section counts match")
    func performUpdatesWithFallback_appliesDiffs_whenSectionCountsMatch() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        let viewController = UIViewController()
        window.rootViewController = viewController
        window.makeKeyAndVisible()

        let collectionNode = ASCollectionNode(collectionViewLayout: UICollectionViewFlowLayout())
        collectionNode.frame = window.bounds
        viewController.view.addSubnode(collectionNode)
        _ = collectionNode.view

        let adapter = ListAdapter(updater: ListAdapterUpdater(),
                                  viewController: viewController,
                                  workingRangeSize: 0)
        let dataSource = TestListAdapterDataSource(items: [])
        adapter.dataSource = dataSource
        adapter.setCollectionNode(collectionNode)

        // 0 → 2 sections through the fallback-aware entry point.
        dataSource.items = [TestItem(id: 1), TestItem(id: 2)]
        await adapter.performUpdatesWithFallback(animated: false)
        collectionNode.view.layoutIfNeeded()
        #expect(collectionNode.view.numberOfSections == 2)

        // 2 → 4 sections through the fallback-aware entry point on a subsequent diff.
        dataSource.items = [TestItem(id: 1), TestItem(id: 2), TestItem(id: 3), TestItem(id: 4)]
        await adapter.performUpdatesWithFallback(animated: false)
        collectionNode.view.layoutIfNeeded()
        #expect(collectionNode.view.numberOfSections == 4)
    }

    // NOTE: There is no companion regression test that exercises the
    // `reloadData(completion:)` fallback branch in `performUpdatesWithFallback`. The branch is
    // reached when `collectionView.numberOfSections != adapter.objects().count`, a state
    // that the IGListKit + AsyncDisplayKit API contract intentionally prevents callers
    // from constructing directly:
    //
    //   - Swapping `collectionNode.dataSource` to a non-bridge stand-in crashes during
    //     layout: AsyncDisplayKit's interop layer dispatches UIKit-historical selectors
    //     (`collectionView:cellForItemAtIndexPath:` etc.) at the data source, and only
    //     `IGListAdapterDataSourceBridge` runtime-conforms to them. A `UIKit`/`ASDK`
    //     data source that omits the runtime conformance hits "unrecognized selector"
    //     on the first cell dequeue.
    //   - Subclassing `ListAdapter` to stub `objects()` fails at compile time because
    //     `IGListAdapter` is not declared `open` outside its defining module.
    //   - Method swizzling `UICollectionView.numberOfSections` leaks across other tests
    //     in the same process and breaks the unrelated bridge-regression coverage above.
    //
    // The fallback branch is a single `if` with a small body and is verified by
    // inspection of `performUpdatesWithFallback(animated:completion:)` in
    // `IGListAdapter+Texture.swift`. The two tests above (happy path; nil collection
    // view) catch regressions in the surrounding contract (signature, completion
    // semantics, no-op forwarding) that would otherwise mask a broken fallback.

    /// `performUpdatesWithFallback` must remain callable before a collection view is attached.
    /// IGListAdapter accepts `performUpdates` with no collection view (it becomes a
    /// no-op that still invokes completion), and the guard must not change that
    /// contract — it should fall through to `performUpdates` directly without
    /// dereferencing the nil view.
    ///
    /// The completion's `Bool` argument matches whatever the underlying
    /// `performUpdates` returns in this state (typically `false`, since no batch
    /// update actually ran). The contract this test enforces is "does not crash and
    /// invokes the completion handler exactly once" — the specific value is incidental.
    @Test("performUpdatesWithFallback is a no-op when no collection view is attached")
    func performUpdatesWithFallback_isNoOp_whenNoCollectionViewAttached() async {
        let adapter = ListAdapter(updater: ListAdapterUpdater(),
                                  viewController: nil,
                                  workingRangeSize: 0)
        let dataSource = TestListAdapterDataSource(items: [TestItem(id: 1)])
        adapter.dataSource = dataSource

        // No setCollectionNode call — adapter.collectionView is nil. The guard's nil
        // branch forwards to performUpdates. Test must not crash and must receive the
        // callback.
        _ = await adapter.performUpdatesWithFallback(animated: false)
    }
}

// MARK: - Fixtures

private final class TestItem: NSObject, ListDiffable {
    let id: Int

    init(id: Int) {
        self.id = id
    }

    func diffIdentifier() -> NSObjectProtocol {
        return id as NSNumber
    }

    func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
        return (object as? TestItem)?.id == id
    }
}

@MainActor
private final class TestListAdapterDataSource: NSObject, ListAdapterDataSource {
    var items: [TestItem]

    init(items: [TestItem]) {
        self.items = items
    }

    func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
        return items
    }

    func listAdapter(_ listAdapter: ListAdapter,
                     sectionControllerFor object: Any) -> ListSectionController {
        return TestSectionController()
    }

    func emptyView(for listAdapter: ListAdapter) -> UIView? {
        return nil
    }
}

@MainActor
private final class HeaderTestDataSource: NSObject, ListAdapterDataSource {
    var items: [TestItem]

    init(items: [TestItem]) {
        self.items = items
    }

    func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
        return items
    }

    func listAdapter(_ listAdapter: ListAdapter,
                     sectionControllerFor object: Any) -> ListSectionController {
        return HeaderTestSectionController()
    }

    func emptyView(for listAdapter: ListAdapter) -> UIView? {
        return nil
    }
}

private final class HeaderTestSectionController: ListSectionController,
    @preconcurrency ASSectionController,
    @preconcurrency ASSupplementaryNodeSource,
    @preconcurrency ListSupplementaryViewSource {
    override init() {
        super.init()
        self.supplementaryViewSource = self
    }

    // MARK: - ListSectionController (item)

    override public func sizeForItem(at index: Int) -> CGSize {
        return .zero
    }

    override public func cellForItem(at index: Int) -> UICollectionViewCell {
        guard let cellClass = NSClassFromString("_ASCollectionViewCell"),
              let collectionContext = self.collectionContext else {
            return UICollectionViewCell()
        }
        return collectionContext.dequeueReusableCell(of: cellClass as! UICollectionViewCell.Type,
                                                    for: self,
                                                    at: index)
    }

    // MARK: - ASSectionController

    public func nodeBlockForItem(at index: Int) -> ASCellNodeBlock {
        return {
            let node = ASCellNode()
            node.style.preferredSize = CGSize(width: 320, height: 44)
            return node
        }
    }

    public func sizeRangeForItem(at index: Int) -> ASSizeRange {
        return ASSizeRange(min: CGSize(width: 100, height: 44),
                           max: CGSize(width: 320, height: 44))
    }

    // MARK: - ListSupplementaryViewSource

    @MainActor
    public func supportedElementKinds() -> [String] {
        return [UICollectionView.elementKindSectionHeader]
    }

    public func viewForSupplementaryElement(ofKind elementKind: String,
                                            at index: Int) -> UICollectionReusableView {
        guard let reusableViewClass = NSClassFromString("_ASCollectionReusableView"),
              let collectionContext = self.collectionContext else {
            return UICollectionReusableView()
        }
        return collectionContext.dequeueReusableSupplementaryView(
            ofKind: elementKind,
            for: self,
            class: reusableViewClass as! UICollectionReusableView.Type,
            at: index
        )
    }

    public func sizeForSupplementaryView(ofKind elementKind: String, at index: Int) -> CGSize {
        return .zero
    }

    // MARK: - ASSupplementaryNodeSource

    public func nodeBlockForSupplementaryElement(ofKind elementKind: String,
                                                 at index: Int) -> ASCellNodeBlock {
        return {
            let node = ASCellNode()
            node.style.preferredSize = CGSize(width: 320, height: 32)
            return node
        }
    }

    public func sizeRangeForSupplementaryElement(ofKind elementKind: String,
                                                 at index: Int) -> ASSizeRange {
        return ASSizeRange(min: CGSize(width: 100, height: 32),
                           max: CGSize(width: 320, height: 32))
    }
}

private final class TestSectionController: ListSectionController, @preconcurrency ASSectionController {
    override public func sizeForItem(at index: Int) -> CGSize {
        return .zero
    }

    override public func cellForItem(at index: Int) -> UICollectionViewCell {
        // Inlines `SectionControllerMethods.cellForItem(at:sectionController:)`
        // to avoid the @MainActor static helper in this non-isolated context.
        // The end behaviour is identical: ASCollectionView's interop layer
        // wraps a node-backed cell into a `_ASCollectionReusableView`-style
        // class, which routes back through the bridge for the actual node.
        guard let cellClass = NSClassFromString("_ASCollectionViewCell"),
              let collectionContext = self.collectionContext else {
            return UICollectionViewCell()
        }
        return collectionContext.dequeueReusableCell(of: cellClass as! UICollectionViewCell.Type,
                                                    for: self,
                                                    at: index)
    }

    public func nodeBlockForItem(at index: Int) -> ASCellNodeBlock {
        return {
            let node = ASCellNode()
            node.style.preferredSize = CGSize(width: 320, height: 44)
            return node
        }
    }

    public func sizeRangeForItem(at index: Int) -> ASSizeRange {
        return ASSizeRange(min: CGSize(width: 100, height: 44),
                           max: CGSize(width: 320, height: 44))
    }
}
