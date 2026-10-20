import AppKit
import SwiftUI

/// Internal snapshot and projection types shared by the native controller.
struct TreeNodeSnapshot {
    let id: AnyHashable
    let title: String
    let searchableText: String
    let depth: Int
    let rowHeight: CGFloat
    let disclosureCenterOffset: CGFloat
    let content: AnyView
    let interactiveHitTest: (CGPoint, CGSize) -> Bool
    let children: [TreeNodeSnapshot]
}

struct TreeStructureSignature: Equatable {
    let id: AnyHashable
    let title: String
    let searchableText: String
    let rowHeight: CGFloat
    let disclosureCenterOffset: CGFloat
    let children: [TreeStructureSignature]

    init(_ snapshot: TreeNodeSnapshot) {
        id = snapshot.id
        title = snapshot.title
        searchableText = snapshot.searchableText
        rowHeight = snapshot.rowHeight
        disclosureCenterOffset = snapshot.disclosureCenterOffset
        children = snapshot.children.map(TreeStructureSignature.init)
    }
}

final class TreeOutlineItem: NSObject {
    var snapshot: TreeNodeSnapshot
    var allChildren: [TreeOutlineItem] = []
    var children: [TreeOutlineItem] = []

    init(snapshot: TreeNodeSnapshot) { self.snapshot = snapshot }
}

struct TreeProjection {
    let rootItems: [TreeOutlineItem]
    let itemsByID: [AnyHashable: TreeOutlineItem]
    let allItemsByID: [AnyHashable: TreeOutlineItem]
    let structureSignature: TreeStructureSignature

    init(root: TreeNodeSnapshot, query: String, previousItems: [AnyHashable: TreeOutlineItem]) {
        structureSignature = TreeStructureSignature(root)
        var allItems: [AnyHashable: TreeOutlineItem] = [:]
        func buildAll(_ snapshot: TreeNodeSnapshot) -> TreeOutlineItem {
            let item = previousItems[snapshot.id] ?? TreeOutlineItem(snapshot: snapshot)
            item.snapshot = snapshot
            item.allChildren = snapshot.children.map(buildAll)
            allItems[snapshot.id] = item
            return item
        }
        let fullRoot = buildAll(root)
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var visibleItems: [AnyHashable: TreeOutlineItem] = [:]
        func filter(_ item: TreeOutlineItem) -> TreeOutlineItem? {
            let children = item.allChildren.compactMap(filter)
            let matches = normalizedQuery.isEmpty || item.snapshot.searchableText.localizedCaseInsensitiveContains(normalizedQuery)
            guard normalizedQuery.isEmpty || matches || !children.isEmpty else { return nil }
            item.children = children
            visibleItems[item.snapshot.id] = item
            return item
        }
        rootItems = filter(fullRoot).map { [$0] } ?? []
        itemsByID = visibleItems
        allItemsByID = allItems
    }

    static func expansionIDs(for items: [TreeOutlineItem], query: String, savedIDs: Set<AnyHashable>) -> Set<AnyHashable> {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            var result = Set<AnyHashable>()
            func visit(_ item: TreeOutlineItem) {
                if !item.children.isEmpty { result.insert(item.snapshot.id) }
                item.children.forEach(visit)
            }
            items.forEach(visit)
            return result
        }
        return savedIDs
    }

    func isDescendant(_ targetID: AnyHashable, of sourceID: AnyHashable) -> Bool {
        guard let source = allItemsByID[sourceID] else { return false }
        func contains(_ item: TreeOutlineItem) -> Bool {
            item.allChildren.contains { $0.snapshot.id == targetID || contains($0) }
        }
        return contains(source)
    }

    func depth(of id: AnyHashable) -> Int {
        func find(_ item: TreeOutlineItem, depth: Int) -> Int? {
            if item.snapshot.id == id { return depth }
            for child in item.children { if let found = find(child, depth: depth + 1) { return found } }
            return nil
        }
        return rootItems.compactMap { find($0, depth: 0) }.first ?? 0
    }

}

struct TreeDropPlan {
    let targetID: AnyHashable
    let placement: TreeMovePlacement
    let proposedItem: TreeOutlineItem
    let proposedChildIndex: Int

    static func make(proposedItem: Any?, childIndex: Int) -> TreeDropPlan? {
        guard let proposed = proposedItem as? TreeOutlineItem else { return nil }
        if childIndex == NSOutlineViewDropOnItemIndex {
            return TreeDropPlan(targetID: proposed.snapshot.id, placement: .inside, proposedItem: proposed, proposedChildIndex: NSOutlineViewDropOnItemIndex)
        }
        let siblings = proposed.children
        if siblings.isEmpty {
            return TreeDropPlan(targetID: proposed.snapshot.id, placement: .inside, proposedItem: proposed, proposedChildIndex: NSOutlineViewDropOnItemIndex)
        }
        if childIndex <= 0 {
            guard let first = siblings.first else { return nil }
            return TreeDropPlan(targetID: first.snapshot.id, placement: .before, proposedItem: proposed, proposedChildIndex: 0)
        }
        if childIndex >= siblings.count {
            guard let last = siblings.last else { return nil }
            return TreeDropPlan(targetID: last.snapshot.id, placement: .after, proposedItem: proposed, proposedChildIndex: siblings.count)
        }
        return TreeDropPlan(targetID: siblings[childIndex].snapshot.id, placement: .before, proposedItem: proposed, proposedChildIndex: childIndex)
    }
}
