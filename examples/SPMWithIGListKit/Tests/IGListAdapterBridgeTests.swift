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
    ///
    /// A non-standard supplementary kind is used so the bridge takes the
    /// legacy `UICollectionReusableView()` fallback path that handles kinds
    /// the placeholder isn't registered for. The header/footer dequeue path is
    /// covered by `setCollectionNode_registersPlaceholderSupplementaryForBothKinds`
    /// — those two paths cannot be exercised here because
    /// `dequeueReusableSupplementaryView` queries the flow layout's
    /// `layoutAttributesForSupplementaryView(ofKind:at:)` and raises
    /// "request for layout attributes … in section N when there are only M
    /// sections" for out-of-range index paths (an artificial precondition
    /// constructed only by this direct-selector test; production UIKit never
    /// calls the bridge with an index the layout has not approved).
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
        // Use a non-header/footer kind so the bridge takes its legacy
        // `UICollectionReusableView()` fallback path (header and footer route
        // through `dequeueReusableSupplementaryView`, which the unit-test
        // environment cannot exercise for out-of-range index paths — see
        // docstring above).
        let customKind = "TextureIGListKitExtensions.test.customSupplementaryKind"
        // Must not crash — returns a zero-size placeholder instead of throwing.
        let view = fn(bridgeObj, sel, collectionNode.view,
                      customKind as NSString,
                      staleIndexPath)
        #expect(view is UICollectionReusableView,
                "Bridge must return a placeholder view for a stale section, not crash via IGListAdapter")
        // Note: the supplementary-view guard, in production, routes through
        // `dequeueReusableSupplementaryView(ofKind:withReuseIdentifier:for:)` so the
        // returned view carries a reuse identifier (same UIKit contract that
        // applies to cells; `UICollectionView.m` asserts when a supplementary view
        // returned from this delegate has none). That code path is not exercisable
        // in this unit test: UIKit's dequeue implementation queries the layout's
        // `layoutAttributesForSupplementaryView(ofKind:at:)` and raises
        // "request for layout attributes for supplementary view … in section N
        // when there are only M sections in the collection view" when the
        // requested section is out of range. The test reaches the guard only by
        // calling the bridge selector with an out-of-range index path
        // (`section: 2` while `collectionView.numberOfSections == 1`), which is
        // an artificial precondition — in production UIKit only calls this
        // delegate for index paths the layout has already approved, so the dequeue
        // path passes layout validation and the placeholder reuse identifier
        // sticks. Cell-side coverage in
        // `bridge_returnsPlaceholder_forStaleCellAfterSectionRemoval` exercises
        // the equivalent dequeue path (cells don't go through the same layout
        // validation, so the test can verify reuseIdentifier directly).
    }

    /// `IGListAdapter+UICollectionView.m` has a second cell assertion distinct
    /// from the section-removal one: when the section controller exists but
    /// `sectionController.cellForItemAtIndex:` returns nil for the requested
    /// item (typically because UIKit's stale layout asks for an item index
    /// outside `sectionController.numberOfItems`), `IGListAdapter` asserts at
    /// ~line 53 with "Returned a nil cell at indexPath … from section
    /// controller: …".
    ///
    /// The bridge guard verifies `indexPath.item < sectionController.numberOfItems`
    /// before forwarding, so this branch dequeues the placeholder cell instead
    /// of letting IGListAdapter assert. The test drives a valid in-range section
    /// (so `sectionController(forSection:)` returns a controller) and an
    /// out-of-range item (so the second assertion path is the one we exercise).
    @Test("bridge returns placeholder when item index is out of range for section controller")
    func bridge_returnsPlaceholder_whenItemIndexIsOutOfRangeForSectionController() async {
        let placeholderId = "TextureIGListKitExtensions.placeholderCell"

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

        dataSource.items = [TestItem(id: 1)]
        await withCheckedContinuation { continuation in
            adapter.performUpdates(animated: false) { _ in continuation.resume() }
        }
        collectionNode.view.layoutIfNeeded()
        #expect(collectionNode.view.numberOfSections == 1)

        let bridge = collectionNode.dataSource
        guard let bridgeObj = bridge as? NSObject else {
            Issue.record("collectionNode.dataSource is not NSObject — bridge not installed")
            return
        }
        let sel = NSSelectorFromString("collectionView:cellForItemAtIndexPath:")
        guard bridgeObj.responds(to: sel) else {
            Issue.record("Bridge does not respond to cellForItemAtIndexPath:")
            return
        }
        let imp = bridgeObj.method(for: sel)
        typealias CellFn = @convention(c) (NSObject, Selector, UICollectionView, IndexPath) -> UICollectionViewCell
        let fn = unsafeBitCast(imp, to: CellFn.self)
        // Valid section (0), but `TestSectionController.numberOfItems` is the
        // default 1, so item index 5 is out of range. Without the guard,
        // IGListAdapter forwards to a section controller that returns nil and
        // asserts at IGListAdapter+UICollectionView.m:53.
        let outOfRangeIndexPath = IndexPath(item: 5, section: 0)
        let cell = fn(bridgeObj, sel, collectionNode.view, outOfRangeIndexPath)
        #expect(cell.reuseIdentifier == placeholderId,
                "Bridge must dequeue the registered placeholder when item index is out of range for section controller; otherwise IGListAdapter asserts at IGListAdapter+UICollectionView.m:53")
    }

    /// `IGListAdapter+UICollectionView.m` has a second supplementary assertion
    /// distinct from the one the section-removal test exercises: when the section
    /// controller for an in-range index path exists but its
    /// `supplementaryViewSource` is `nil` (or the source does not list the
    /// requested kind in `supportedElementKinds()`), `IGListAdapter` asserts at
    /// ~line 99 with "Returned a nil supplementary-view from source (null) …".
    /// This happens in production when a refresh swaps a populated section
    /// controller for an empty-state one (e.g. an "empty list" controller) that
    /// does not provide headers — UIKit's cached layout attributes still expect a
    /// header for that index, and the section controller's nil source produces a
    /// nil view that IGListAdapter rejects.
    ///
    /// The test uses `TestSectionController`, which (unlike
    /// `HeaderTestSectionController`) does not install a supplementary view
    /// source. Calling the bridge selector at a valid in-range section must
    /// short-circuit to the placeholder path instead of forwarding to
    /// IGListAdapter.
    @Test("bridge returns placeholder when section controller has no supplementary view source")
    func bridge_returnsPlaceholder_whenSectionControllerHasNoSupplementarySource() async {
        let placeholderId = "TextureIGListKitExtensions.placeholderSupplementaryView"

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

        dataSource.items = [TestItem(id: 1)]
        await withCheckedContinuation { continuation in
            adapter.performUpdates(animated: false) { _ in continuation.resume() }
        }
        collectionNode.view.layoutIfNeeded()
        #expect(collectionNode.view.numberOfSections == 1)

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
        // Valid in-range index path. TestSectionController has no
        // supplementaryViewSource, so without the bridge guard IGListAdapter
        // forwards `viewForSupplementaryElementOfKind:` to nil and asserts.
        let indexPath = IndexPath(item: 0, section: 0)
        let view = fn(bridgeObj, sel, collectionNode.view,
                      UICollectionView.elementKindSectionHeader as NSString,
                      indexPath)
        #expect(view.reuseIdentifier == placeholderId,
                "Bridge must dequeue the registered placeholder when the section controller has no supplementaryViewSource; otherwise IGListAdapter asserts at IGListAdapter+UICollectionView.m:99")
    }

    /// Verifies that `setCollectionNode(_:)` registers the bridge's placeholder
    /// supplementary view against both standard kinds (header and footer). The
    /// placeholder is what the stale-section guard in
    /// `collectionView:viewForSupplementaryElementOfKind:atIndexPath:` dequeues to
    /// satisfy UIKit's reuseIdentifier contract when the requested section has
    /// been removed from the adapter's section map.
    ///
    /// Calling `dequeueReusableSupplementaryView(ofKind:withReuseIdentifier:for:)`
    /// directly with a valid in-range index path (section 0) sidesteps the layout
    /// validation that prevents an out-of-range index from being verified inside a
    /// unit test (`UICollectionViewFlowLayout` asserts "request for layout
    /// attributes … in section N when there are only M sections" for out-of-range
    /// queries). In production UIKit only calls the bridge for index paths the
    /// layout has already approved, so the dequeue path always passes that
    /// validation.
    @Test("setCollectionNode registers placeholder for header and footer supplementary kinds")
    func setCollectionNode_registersPlaceholderSupplementaryForBothKinds() async {
        let placeholderId = "TextureIGListKitExtensions.placeholderSupplementaryView"

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
        // Initial items intentionally empty so the bridge wire-up in
        // setCollectionNode does not race with the first IGListAdapter reload — the
        // same setup pattern the other regression tests in this file use.
        let dataSource = TestListAdapterDataSource(items: [])
        adapter.dataSource = dataSource
        adapter.setCollectionNode(collectionNode)

        dataSource.items = [TestItem(id: 1)]
        await withCheckedContinuation { continuation in
            adapter.performUpdates(animated: false) { _ in continuation.resume() }
        }
        collectionNode.view.layoutIfNeeded()
        #expect(collectionNode.view.numberOfSections == 1)

        let indexPath = IndexPath(item: 0, section: 0)
        let headerView = collectionNode.view.dequeueReusableSupplementaryView(
            ofKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: placeholderId,
            for: indexPath
        )
        #expect(headerView.reuseIdentifier == placeholderId,
                "setCollectionNode must register placeholder for elementKindSectionHeader; dequeue otherwise throws 'no view registered for identifier'")

        let footerView = collectionNode.view.dequeueReusableSupplementaryView(
            ofKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: placeholderId,
            for: indexPath
        )
        #expect(footerView.reuseIdentifier == placeholderId,
                "setCollectionNode must register placeholder for elementKindSectionFooter; dequeue otherwise throws 'no view registered for identifier'")
    }

    /// After `performUpdates` removes sections, IGListKit's internal section-count
    /// fallback (`[IGListBatchUpdateTransaction _reload]`) issues
    /// `[UICollectionView reloadData]` followed by `layoutBelowIfNeeded`, which
    /// continues to request cells based on layout attributes cached from the
    /// previous state — i.e. for sections that no longer exist in the adapter's
    /// section map. Without the bridge guard, `IGListAdapter` asserts at
    /// `IGListAdapter+UICollectionView.m:47` with
    /// "Section controller is nil { … sectionController: (null), dataSource: <…> }".
    ///
    /// This test calls the bridge's Interop `cellForItemAtIndexPath:` selector
    /// directly with a section index that was removed by a preceding
    /// `performUpdates` — the call must return a placeholder cell without crashing.
    @Test("bridge returns placeholder cell for stale section after removal")
    func bridge_returnsPlaceholder_forStaleCellAfterSectionRemoval() async {
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

        // Simulate UICollectionView requesting a cell for the now-removed section 2.
        // Without the bridge guard, IGListAdapter asserts at
        // IGListAdapter+UICollectionView.m:47.
        let bridge = collectionNode.dataSource
        guard let bridgeObj = bridge as? NSObject else {
            Issue.record("collectionNode.dataSource is not NSObject — bridge not installed")
            return
        }
        let sel = NSSelectorFromString("collectionView:cellForItemAtIndexPath:")
        guard bridgeObj.responds(to: sel) else {
            Issue.record("Bridge does not respond to cellForItemAtIndexPath:")
            return
        }
        let imp = bridgeObj.method(for: sel)
        typealias CellFn = @convention(c) (NSObject, Selector, UICollectionView, IndexPath) -> UICollectionViewCell
        let fn = unsafeBitCast(imp, to: CellFn.self)
        let staleIndexPath = IndexPath(item: 0, section: 2)
        // Must not crash — returns a placeholder cell instead of asserting.
        let cell = fn(bridgeObj, sel, collectionNode.view, staleIndexPath)
        #expect(type(of: cell) == UICollectionViewCell.self,
                "Bridge must return a vanilla placeholder cell for a stale section, not crash via IGListAdapter")
        // UIKit asserts at UICollectionView.m:3930 ("The collection view's data
        // source returned a cell without a reuseIdentifier.") when a cell returned
        // from `collectionView:cellForItemAtIndexPath:` has no reuse identifier
        // set. The placeholder must therefore be dequeued (not directly
        // constructed) so it carries one.
        #expect(cell.reuseIdentifier != nil,
                "Placeholder cell must be dequeued so it carries a reuseIdentifier; UIKit asserts at UICollectionView.m:3930 when a returned cell has none")
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
