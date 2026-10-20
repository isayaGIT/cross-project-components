import AppKit
import SwiftUI
import XCTest
@testable import CrossProjectComponents

final class TreeViewTests: XCTestCase {
    func testSearchKeepsMatchesAndEveryAncestor() {
        let leaf = snapshot("leaf", "Lighting Design")
        let design = snapshot("design", "Design", children: [leaf])
        let rooms = snapshot("rooms", "Rooms", children: [design, snapshot("bath", "Bathroom")])
        let root = snapshot("root", "ZPing", children: [rooms, snapshot("character", "Character")])

        let projection = TreeProjection(root: root, query: "lighting", previousItems: [:])
        XCTAssertEqual(projection.rootItems.map { $0.snapshot.title }, ["ZPing"])
        XCTAssertEqual(projection.rootItems[0].children.map { $0.snapshot.title }, ["Rooms"])
        XCTAssertEqual(projection.rootItems[0].children[0].children.map { $0.snapshot.title }, ["Design"])
        XCTAssertEqual(projection.rootItems[0].children[0].children[0].children.map { $0.snapshot.title }, ["Lighting Design"])
        XCTAssertEqual(projection.itemsByID.count, 4)
    }

    func testProjectionReusesStableItemsAcrossModelUpdatesAndFilters() {
        let child = snapshot("child", "Old title")
        let root = snapshot("root", "Root", children: [child, snapshot("other", "Other")])
        let first = TreeProjection(root: root, query: "", previousItems: [:])
        let replacement = snapshot("child", "New title")
        let second = TreeProjection(root: snapshot("root", "Root", children: [replacement, snapshot("other", "Other")]), query: "new", previousItems: first.allItemsByID)
        let cleared = TreeProjection(root: snapshot("root", "Root", children: [replacement, snapshot("other", "Other")]), query: "", previousItems: second.allItemsByID)

        XCTAssertTrue(first.allItemsByID[AnyHashable("child")] === second.allItemsByID[AnyHashable("child")])
        XCTAssertTrue(second.allItemsByID[AnyHashable("child")] === cleared.allItemsByID[AnyHashable("child")])
        XCTAssertEqual(cleared.allItemsByID[AnyHashable("child")]?.snapshot.title, "New title")
        XCTAssertEqual(cleared.itemsByID.count, 3)
    }

    func testSearchUsesHostProvidedSearchableTextRatherThanDisplayTitle() {
        let searchable = snapshot("root", "Root", children: [
            snapshot("child", "Short name", searchableText: "Short name | product design | lighting", depth: 1)
        ])
        let projection = TreeProjection(root: searchable, query: "lighting", previousItems: [:])
        XCTAssertEqual(projection.itemsByID.count, 2)
        XCTAssertNotNil(projection.allItemsByID[AnyHashable("child")])
    }

    func testSearchExpansionDoesNotReplaceSavedExpansionSet() {
        let root = snapshot("root", "Root", children: [snapshot("branch", "Branch", children: [snapshot("match", "Match")])])
        let saved: Set<AnyHashable> = [AnyHashable("root")]
        let filtered = TreeProjection(root: root, query: "match", previousItems: [:])
        XCTAssertEqual(TreeProjection.expansionIDs(for: filtered.rootItems, query: "match", savedIDs: saved), Set([AnyHashable("root"), AnyHashable("branch")]))
        XCTAssertEqual(TreeProjection.expansionIDs(for: filtered.rootItems, query: "", savedIDs: saved), saved)
    }

    func testProjectionRejectsDroppingANodeIntoItsOwnDescendant() {
        let tree = snapshot("root", "Root", children: [
            snapshot("parent", "Parent", children: [snapshot("child", "Child")]),
            snapshot("sibling", "Sibling")
        ])
        let projection = TreeProjection(root: tree, query: "", previousItems: [:])
        XCTAssertTrue(projection.isDescendant(AnyHashable("child"), of: AnyHashable("parent")))
        XCTAssertFalse(projection.isDescendant(AnyHashable("sibling"), of: AnyHashable("parent")))
        XCTAssertFalse(projection.isDescendant(AnyHashable("parent"), of: AnyHashable("parent")))
    }

    func testDropProposalMapsInsideBeforeBetweenAndAfter() {
        let first = item("first")
        let second = item("second")
        let third = item("third")
        let parent = item("parent", children: [first, second, third])

        let inside = TreeDropPlan.make(proposedItem: parent, childIndex: NSOutlineViewDropOnItemIndex)
        let before = TreeDropPlan.make(proposedItem: parent, childIndex: 0)
        let between = TreeDropPlan.make(proposedItem: parent, childIndex: 1)
        let after = TreeDropPlan.make(proposedItem: parent, childIndex: 3)

        XCTAssertEqual(inside?.targetID, AnyHashable("parent"))
        XCTAssertEqual(inside?.placement, .inside)
        XCTAssertEqual(before?.targetID, AnyHashable("first"))
        XCTAssertEqual(before?.placement, .before)
        XCTAssertEqual(between?.targetID, AnyHashable("second"))
        XCTAssertEqual(between?.placement, .before)
        XCTAssertEqual(after?.targetID, AnyHashable("third"))
        XCTAssertEqual(after?.placement, .after)
    }

    func testDropIntoEmptyNodeMeansInsideAndUnknownTargetsAreRejected() {
        let empty = item("empty")
        let plan = TreeDropPlan.make(proposedItem: empty, childIndex: 0)
        XCTAssertEqual(plan?.targetID, AnyHashable("empty"))
        XCTAssertEqual(plan?.placement, .inside)
        XCTAssertNil(TreeDropPlan.make(proposedItem: NSObject(), childIndex: 0))
    }

    private func snapshot(_ id: String, _ title: String, searchableText: String? = nil, depth: Int = 0, children: [TreeNodeSnapshot] = []) -> TreeNodeSnapshot {
        TreeNodeSnapshot(id: AnyHashable(id), title: title, searchableText: searchableText ?? title, depth: depth, rowHeight: 32, disclosureCenterOffset: 16, content: AnyView(EmptyView()), interactiveHitTest: { _, _ in false }, children: children)
    }

    private func item(_ id: String, children: [TreeOutlineItem] = []) -> TreeOutlineItem {
        let node = TreeOutlineItem(snapshot: snapshot(id, id, children: []))
        node.allChildren = children
        node.children = children
        return node
    }
}
