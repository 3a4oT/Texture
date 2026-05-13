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
