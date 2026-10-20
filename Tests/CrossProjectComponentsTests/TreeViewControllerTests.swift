import AppKit
import SwiftUI
import XCTest
@testable import CrossProjectComponents

final class TreeViewControllerTests: XCTestCase {
    func testNativeOutlineRendersExpandedHierarchyAndCustomRowHeights() {
        XCTAssertTrue(Thread.isMainThread, "AppKit view tests must execute on the main thread.")
        _ = NSApplication.shared

        let leaf = snapshot("leaf", "Lighting Design", rowHeight: 32)
        let branch = snapshot("branch", "Design", rowHeight: 78, children: [leaf])
        let root = snapshot("root", "ZPing", rowHeight: 32, children: [branch])
        let controller = TreeViewController()
        controller.view.frame = NSRect(x: 0, y: 0, width: 320, height: 480)

        var selectedIDs: [AnyHashable?] = []
        var toggledIDs: [AnyHashable] = []
        controller.update(
            root: root,
            selectedID: AnyHashable("leaf"),
            expandedIDs: [AnyHashable("root"), AnyHashable("branch")],
            searchText: "",
            canMove: { _, _, _ in true },
            onSelect: { selectedIDs.append($0) },
            onToggleExpanded: { toggledIDs.append($0) },
            onMove: { _, _, _ in },
            onRowInteraction: { _ in }
        )
        controller.view.layoutSubtreeIfNeeded()

        let outline = try! XCTUnwrap(findOutline(in: controller.view))
        XCTAssertEqual(outline.numberOfRows, 3)
        XCTAssertEqual(outline.selectedRow, 2)

        let branchItem = try! XCTUnwrap(outline.item(atRow: 1) as? TreeOutlineItem)
        let leafItem = try! XCTUnwrap(outline.item(atRow: 2) as? TreeOutlineItem)
        XCTAssertTrue(outline.isItemExpanded(outline.item(atRow: 0)))
        XCTAssertTrue(outline.isItemExpanded(branchItem))
        XCTAssertEqual(controller.outlineView(outline, heightOfRowByItem: branchItem), 78)
        XCTAssertEqual(controller.outlineView(outline, heightOfRowByItem: leafItem), 32)

        outline.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        XCTAssertEqual(selectedIDs.last as? AnyHashable, AnyHashable("branch"))

        outline.collapseItem(branchItem)
        XCTAssertFalse(outline.isItemExpanded(branchItem))
        XCTAssertTrue(toggledIDs.contains(AnyHashable("branch")))
        XCTAssertEqual(outline.numberOfRows, 2)
    }

    func testNativeOutlineSearchUsesFilteredProjectionWithoutChangingSavedExpansion() {
        XCTAssertTrue(Thread.isMainThread, "AppKit view tests must execute on the main thread.")
        _ = NSApplication.shared

        let root = snapshot("root", "ZPing", children: [
            snapshot("rooms", "Rooms", children: [
                snapshot("design", "Design", children: [
                    snapshot("lighting", "Lighting Design")
                ]),
                snapshot("bath", "Bathroom")
            ]),
            snapshot("character", "Character")
        ])
        let controller = TreeViewController()
        controller.view.frame = NSRect(x: 0, y: 0, width: 320, height: 480)
        let savedExpansion: Set<AnyHashable> = [AnyHashable("root"), AnyHashable("rooms")]
        var toggledIDs: [AnyHashable] = []

        func update(query: String) {
            controller.update(
                root: root,
                selectedID: nil,
                expandedIDs: savedExpansion,
                searchText: query,
                canMove: { _, _, _ in true },
                onSelect: { _ in },
                onToggleExpanded: { toggledIDs.append($0) },
                onMove: { _, _, _ in },
                onRowInteraction: { _ in }
            )
        }

        update(query: "lighting")
        controller.view.layoutSubtreeIfNeeded()
        let outline = try! XCTUnwrap(findOutline(in: controller.view))
        XCTAssertEqual((0..<outline.numberOfRows).compactMap { (outline.item(atRow: $0) as? TreeOutlineItem)?.snapshot.title },
                       ["ZPing", "Rooms", "Design", "Lighting Design"])
        XCTAssertTrue(toggledIDs.isEmpty, "Search-only expansion must not mutate the host's saved expansion set.")

        update(query: "")
        controller.view.layoutSubtreeIfNeeded()
        XCTAssertEqual(savedExpansion, [AnyHashable("root"), AnyHashable("rooms")])
        XCTAssertEqual((0..<outline.numberOfRows).compactMap { (outline.item(atRow: $0) as? TreeOutlineItem)?.snapshot.title },
                       ["ZPing", "Rooms", "Design", "Bathroom", "Character"])
        XCTAssertTrue(toggledIDs.isEmpty)
    }

    private func findOutline(in view: NSView) -> NSOutlineView? {
        if let outline = view as? NSOutlineView { return outline }
        for child in view.subviews {
            if let found = findOutline(in: child) { return found }
        }
        if let scrollView = view as? NSScrollView, let outline = scrollView.documentView as? NSOutlineView {
            return outline
        }
        return nil
    }

    private func snapshot(
        _ id: String,
        _ title: String,
        rowHeight: CGFloat = 32,
        children: [TreeNodeSnapshot] = []
    ) -> TreeNodeSnapshot {
        TreeNodeSnapshot(
            id: AnyHashable(id),
            title: title,
            searchableText: title,
            depth: 0,
            rowHeight: rowHeight,
            disclosureCenterOffset: rowHeight / 2,
            content: AnyView(Text(title)),
            interactiveHitTest: { _, _ in false },
            children: children
        )
    }
}
