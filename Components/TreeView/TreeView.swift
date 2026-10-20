import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The only domain contract required by the reusable Tree component.
/// Conform a host model without moving its persistence or mutation rules into this package.
public protocol TreeNodeRepresentable {
    associatedtype ID: Hashable
    var treeID: ID { get }
    var treeTitle: String { get }
    var treeChildren: [Self] { get }
}

/// A placement in the hierarchy, independent of any host application's model enum.
public enum TreeMovePlacement: Equatable, Sendable {
    case before
    case inside
    case after
}

/// State supplied to a host-defined row renderer.
public struct TreeRowContext<Node> {
    public let node: Node
    public let depth: Int
    public let isSelected: Bool
    public let isExpanded: Bool
    public let hasChildren: Bool

    public init(node: Node, depth: Int, isSelected: Bool, isExpanded: Bool, hasChildren: Bool) {
        self.node = node
        self.depth = depth
        self.isSelected = isSelected
        self.isExpanded = isExpanded
        self.hasChildren = hasChildren
    }
}

/// A native macOS hierarchical tree with externally controlled selection and expansion.
/// The package owns outline mechanics; the host owns domain validation, mutations and storage.
public struct TreeView<Node: TreeNodeRepresentable, RowContent: View>: NSViewControllerRepresentable {
    public typealias NSViewControllerType = NSViewController
    public let root: Node
    @Binding private var selection: Node.ID?
    @Binding private var expandedIDs: Set<Node.ID>
    public let searchText: String
    private let searchableText: (Node) -> String
    private let rowHeight: (Node, Int) -> CGFloat
    private let disclosureCenterOffset: ((Node, Int) -> CGFloat)?
    private let canMove: (Node.ID, Node.ID, TreeMovePlacement) -> Bool
    private let onMove: (Node.ID, Node.ID, TreeMovePlacement) -> Void
    private let onRowInteraction: (Node.ID) -> Void
    private let interactiveHitTest: (Node, CGPoint, CGSize) -> Bool
    private let rowContent: (TreeRowContext<Node>) -> RowContent

    public init(
        root: Node,
        selection: Binding<Node.ID?>,
        expandedIDs: Binding<Set<Node.ID>>,
        searchText: String = "",
        searchableText: @escaping (Node) -> String = { $0.treeTitle },
        rowHeight: @escaping (Node, Int) -> CGFloat = { _, _ in 32 },
        disclosureCenterOffset: ((Node, Int) -> CGFloat)? = nil,
        canMove: @escaping (Node.ID, Node.ID, TreeMovePlacement) -> Bool,
        onMove: @escaping (Node.ID, Node.ID, TreeMovePlacement) -> Void,
        onRowInteraction: @escaping (Node.ID) -> Void = { _ in },
        interactiveHitTest: @escaping (Node, CGPoint, CGSize) -> Bool = { _, _, _ in false },
        @ViewBuilder rowContent: @escaping (TreeRowContext<Node>) -> RowContent
    ) {
        self.root = root
        self._selection = selection
        self._expandedIDs = expandedIDs
        self.searchText = searchText
        self.searchableText = searchableText
        self.rowHeight = rowHeight
        self.disclosureCenterOffset = disclosureCenterOffset
        self.canMove = canMove
        self.onMove = onMove
        self.onRowInteraction = onRowInteraction
        self.interactiveHitTest = interactiveHitTest
        self.rowContent = rowContent
    }

    public func makeNSViewController(context: Context) -> NSViewController {
        let controller = TreeViewController()
        _ = controller.view
        controller.update(
            root: makeSnapshot(),
            selectedID: selection.map(AnyHashable.init),
            expandedIDs: Set(expandedIDs.map(AnyHashable.init)),
            searchText: searchText,
            canMove: canMoveErased,
            onSelect: { id in self.selection = id?.base as? Node.ID },
            onToggleExpanded: toggleExpanded,
            onMove: moveErased,
            onRowInteraction: { id in
                guard let typedID = id.base as? Node.ID else { return }
                self.onRowInteraction(typedID)
            }
        )
        return controller
    }

    public func updateNSViewController(_ viewController: NSViewController, context: Context) {
        guard let controller = viewController as? TreeViewController else { return }
        controller.update(
            root: makeSnapshot(),
            selectedID: selection.map(AnyHashable.init),
            expandedIDs: Set(expandedIDs.map(AnyHashable.init)),
            searchText: searchText,
            canMove: canMoveErased,
            onSelect: { id in self.selection = id?.base as? Node.ID },
            onToggleExpanded: toggleExpanded,
            onMove: moveErased,
            onRowInteraction: { id in
                guard let typedID = id.base as? Node.ID else { return }
                self.onRowInteraction(typedID)
            }
        )
    }

    private func toggleExpanded(_ id: AnyHashable) {
        guard let typedID = id.base as? Node.ID else { return }
        var next = expandedIDs
        if next.contains(typedID) { next.remove(typedID) } else { next.insert(typedID) }
        expandedIDs = next
    }

    private func canMoveErased(_ source: AnyHashable, _ target: AnyHashable, _ placement: TreeMovePlacement) -> Bool {
        guard let sourceID = source.base as? Node.ID, let targetID = target.base as? Node.ID else { return false }
        return canMove(sourceID, targetID, placement)
    }

    private func moveErased(_ source: AnyHashable, _ target: AnyHashable, _ placement: TreeMovePlacement) {
        guard let sourceID = source.base as? Node.ID, let targetID = target.base as? Node.ID else { return }
        onMove(sourceID, targetID, placement)
    }

    private func makeSnapshot() -> TreeNodeSnapshot {
        let selected = selection
        let expanded = expandedIDs
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        func build(_ node: Node, depth: Int) -> TreeNodeSnapshot {
            let children = node.treeChildren.map { build($0, depth: depth + 1) }
            let hasChildren = !children.isEmpty
            let selectedRow = node.treeID == selected
            let expandedRow = query.isEmpty ? expanded.contains(node.treeID) : hasChildren
            let computedRowHeight = max(1, rowHeight(node, depth))
            let context = TreeRowContext(
                node: node,
                depth: depth,
                isSelected: selectedRow,
                isExpanded: expandedRow,
                hasChildren: hasChildren
            )
            return TreeNodeSnapshot(
                id: AnyHashable(node.treeID),
                title: node.treeTitle,
                searchableText: searchableText(node),
                depth: depth,
                rowHeight: computedRowHeight,
                disclosureCenterOffset: disclosureCenterOffset?(node, depth) ?? computedRowHeight / 2,
                content: AnyView(rowContent(context)),
                interactiveHitTest: { point, size in interactiveHitTest(node, point, size) },
                children: children
            )
        }
        return build(root, depth: 0)
    }
}
