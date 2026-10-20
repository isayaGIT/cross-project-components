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

/// Pointer gesture family considered by the TreeView gesture-layer resolver.
public enum TreeGestureKind: Equatable, Sendable {
    case primaryPointer
    case secondaryPointer
    case otherPointer
}

/// Immutable, host-independent context used to decide which gesture layer owns a pointer sequence.
/// `point` uses top-leading row-content coordinates, matching the row layout API.
public struct TreeGestureHitTestContext {
    public let nodeID: AnyHashable
    public let point: CGPoint
    public let size: CGSize
    public let kind: TreeGestureKind
    public let clickCount: Int
    public let modifierFlags: UInt

    public init(nodeID: AnyHashable, point: CGPoint, size: CGSize, kind: TreeGestureKind, clickCount: Int = 1, modifierFlags: UInt = 0) {
        self.nodeID = nodeID
        self.point = point
        self.size = size
        self.kind = kind
        self.clickCount = clickCount
        self.modifierFlags = modifierFlags
    }
}

/// A host-defined gesture layer. Higher priorities are resolved first; registration order breaks ties.
/// Claiming a pointer sequence routes it to the embedded row view and prevents native Tree gestures
/// from interpreting the same input as selection, dragging, or node editing.
public protocol TreeGestureLayer {
    var priority: Int { get }
    func claims(_ context: TreeGestureHitTestContext) -> Bool
}

/// State supplied to a host-defined row renderer.
public struct TreeRowContext<Node> {
    public let node: Node
    public let depth: Int
    public let isSelected: Bool
    public let isExpanded: Bool
    public let hasChildren: Bool
    public let isEditing: Bool
    public let onRename: (String) -> Void
    public let onCommitEditing: (String) -> Void
    public let shouldFinishEditingOnFocusLoss: () -> Bool

    public init(node: Node, depth: Int, isSelected: Bool, isExpanded: Bool, hasChildren: Bool, isEditing: Bool = false, onRename: @escaping (String) -> Void = { _ in }, onCommitEditing: @escaping (String) -> Void = { _ in }, shouldFinishEditingOnFocusLoss: @escaping () -> Bool = { true }) {
        self.node = node
        self.depth = depth
        self.isSelected = isSelected
        self.isExpanded = isExpanded
        self.hasChildren = hasChildren
        self.isEditing = isEditing
        self.onRename = onRename
        self.onCommitEditing = onCommitEditing
        self.shouldFinishEditingOnFocusLoss = shouldFinishEditingOnFocusLoss
    }
}

private final class TreePointerInteractionTracker {
    private var hasRecentInputTarget = false
    private var targetRowID: AnyHashable?

    func recordInputTarget(_ rowID: AnyHashable?) {
        hasRecentInputTarget = true
        targetRowID = rowID
    }

    func shouldFinishEditingOnFocusLoss(for rowID: AnyHashable) -> Bool {
        guard hasRecentInputTarget else { return true }
        hasRecentInputTarget = false
        defer { targetRowID = nil }
        return targetRowID != rowID
    }
}

/// A native macOS hierarchical tree with externally controlled selection and expansion.
/// The package owns outline mechanics; the host owns domain validation, mutations and storage.
public struct TreeView<Node: TreeNodeRepresentable, RowContent: View>: NSViewControllerRepresentable {
    public typealias NSViewControllerType = NSViewController
    public let root: Node
    @Binding private var selection: Node.ID?
    @Binding private var expandedIDs: Set<Node.ID>
    @Binding private var editingID: Node.ID?
    @Binding private var selectedIDs: Set<Node.ID>
    @State private var pendingCreatedPreviousIDs: [Node.ID: Node.ID] = [:]
    @State private var pointerInteractionTracker = TreePointerInteractionTracker()
    public let searchText: String
    private let searchableText: (Node) -> String
    private let rowHeight: (Node, Int) -> CGFloat
    private let disclosureCenterOffset: ((Node, Int) -> CGFloat)?
    private let canMove: (Node.ID, Node.ID, TreeMovePlacement) -> Bool
    private let onMove: (Node.ID, Node.ID, TreeMovePlacement) -> Void
    private let onCreateSibling: (Node.ID?) -> Node.ID?
    private let onRename: (Node.ID, String) -> Void
    private let contentCount: (Node) -> Int
    private let onDelete: ([Node.ID]) -> Void
    private let onDeleteWithSelection: (([Node.ID], Node.ID?) -> Void)?
    private let onIndent: ([Node.ID]) -> Void
    private let onOutdent: ([Node.ID]) -> Void
    private let canUndo: Bool
    private let canRedo: Bool
    private let onUndo: () -> Void
    private let onRedo: () -> Void
    private let onRowInteraction: (Node.ID) -> Void
    private let interactiveHitTest: (Node, CGPoint, CGSize) -> Bool
    private let gestureLayers: [any TreeGestureLayer]
    private let rowContent: (TreeRowContext<Node>) -> RowContent

    public init(
        root: Node,
        selection: Binding<Node.ID?>,
        expandedIDs: Binding<Set<Node.ID>>,
        editingID: Binding<Node.ID?> = .constant(nil),
        selectedIDs: Binding<Set<Node.ID>> = .constant([]),
        searchText: String = "",
        searchableText: @escaping (Node) -> String = { $0.treeTitle },
        rowHeight: @escaping (Node, Int) -> CGFloat = { _, _ in 32 },
        disclosureCenterOffset: ((Node, Int) -> CGFloat)? = nil,
        canMove: @escaping (Node.ID, Node.ID, TreeMovePlacement) -> Bool,
        onMove: @escaping (Node.ID, Node.ID, TreeMovePlacement) -> Void,
        onCreateSibling: @escaping (Node.ID?) -> Node.ID? = { _ in nil },
        onRename: @escaping (Node.ID, String) -> Void = { _, _ in },
        contentCount: @escaping (Node) -> Int = { _ in 0 },
        onDelete: @escaping ([Node.ID]) -> Void = { _ in },
        onDeleteWithSelection: (([Node.ID], Node.ID?) -> Void)? = nil,
        onIndent: @escaping ([Node.ID]) -> Void = { _ in },
        onOutdent: @escaping ([Node.ID]) -> Void = { _ in },
        canUndo: Bool = false,
        canRedo: Bool = false,
        onUndo: @escaping () -> Void = {},
        onRedo: @escaping () -> Void = {},
        onRowInteraction: @escaping (Node.ID) -> Void = { _ in },
        interactiveHitTest: @escaping (Node, CGPoint, CGSize) -> Bool = { _, _, _ in false },
        gestureLayers: [any TreeGestureLayer] = [],
        @ViewBuilder rowContent: @escaping (TreeRowContext<Node>) -> RowContent
    ) {
        self.root = root
        self._selection = selection
        self._expandedIDs = expandedIDs
        self._editingID = editingID
        self._selectedIDs = selectedIDs
        self.searchText = searchText
        self.searchableText = searchableText
        self.rowHeight = rowHeight
        self.disclosureCenterOffset = disclosureCenterOffset
        self.canMove = canMove
        self.onMove = onMove
        self.onCreateSibling = onCreateSibling
        self.onRename = onRename
        self.contentCount = contentCount
        self.onDelete = onDelete
        self.onDeleteWithSelection = onDeleteWithSelection
        self.onIndent = onIndent
        self.onOutdent = onOutdent
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onRowInteraction = onRowInteraction
        self.interactiveHitTest = interactiveHitTest
        self.gestureLayers = gestureLayers
        self.rowContent = rowContent
    }

    public func makeNSViewController(context: Context) -> NSViewController {
        let controller = TreeViewController()
        _ = controller.view
        controller.update(
            root: makeSnapshot(),
            selectedID: selection.map(AnyHashable.init),
            selectedIDs: Set(selectedIDs.map(AnyHashable.init)),
            expandedIDs: Set(expandedIDs.map(AnyHashable.init)),
            searchText: searchText,
            canMove: canMoveErased,
            onSelect: { id in self.selection = id?.base as? Node.ID },
            onToggleExpanded: toggleExpanded,
            onMove: moveErased,
            onCreateSibling: createSiblingErased,
            onSelectMultiple: { ids in self.selectedIDs = Set(ids.compactMap { $0.base as? Node.ID }) },
            onDelete: deleteErased,
            onIndent: indentErased,
            onOutdent: outdentErased,
            canUndo: canUndo,
            canRedo: canRedo,
            onUndo: { self.onUndo() },
            onRedo: { self.onRedo() },
            onRowInteraction: { id in
                guard let typedID = id.base as? Node.ID else { return }
                self.onRowInteraction(typedID)
            },
            onPointerInteraction: { id in pointerInteractionTracker.recordInputTarget(id) },
            onBeginEditing: { id in
                guard let typedID = id.base as? Node.ID else { return }
                self.selection = typedID
                self.selectedIDs = [typedID]
                self.editingID = typedID
            }
        )
        return controller
    }

    public func updateNSViewController(_ viewController: NSViewController, context: Context) {
        guard let controller = viewController as? TreeViewController else { return }
        controller.update(
            root: makeSnapshot(),
            selectedID: selection.map(AnyHashable.init),
            selectedIDs: Set(selectedIDs.map(AnyHashable.init)),
            expandedIDs: Set(expandedIDs.map(AnyHashable.init)),
            searchText: searchText,
            canMove: canMoveErased,
            onSelect: { id in self.selection = id?.base as? Node.ID },
            onToggleExpanded: toggleExpanded,
            onMove: moveErased,
            onCreateSibling: createSiblingErased,
            onSelectMultiple: { ids in self.selectedIDs = Set(ids.compactMap { $0.base as? Node.ID }) },
            onDelete: deleteErased,
            onIndent: indentErased,
            onOutdent: outdentErased,
            canUndo: canUndo,
            canRedo: canRedo,
            onUndo: { self.onUndo() },
            onRedo: { self.onRedo() },
            onRowInteraction: { id in
                guard let typedID = id.base as? Node.ID else { return }
                self.onRowInteraction(typedID)
            },
            onPointerInteraction: { id in pointerInteractionTracker.recordInputTarget(id) },
            onBeginEditing: { id in
                guard let typedID = id.base as? Node.ID else { return }
                self.selection = typedID
                self.selectedIDs = [typedID]
                self.editingID = typedID
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

    private func createSiblingErased(_ id: AnyHashable?) -> AnyHashable? {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let typedID = id?.base as? Node.ID
        guard let newID = onCreateSibling(typedID) else { return nil }
        let previousID = typedID ?? selection ?? root.treeID
        selection = newID
        selectedIDs = [newID]
        pendingCreatedPreviousIDs[newID] = previousID
        editingID = newID
        return AnyHashable(newID)
    }

    private func deleteErased(_ ids: [AnyHashable], preferredSelection: AnyHashable?) {
        let typed = ids.compactMap { $0.base as? Node.ID }
        guard !typed.isEmpty else { return }
        let fallbackID = preferredSelection?.base as? Node.ID
        if let onDeleteWithSelection {
            onDeleteWithSelection(typed, fallbackID)
        } else {
            onDelete(typed)
        }
        if let fallbackID {
            selection = fallbackID
            selectedIDs = [fallbackID]
        } else {
            selection = nil
            selectedIDs = []
        }
        editingID = nil
    }

    private func previousVisibleID(before targetID: Node.ID) -> Node.ID? {
        var visibleIDs: [Node.ID] = []
        func appendVisible(_ node: Node) {
            visibleIDs.append(node.treeID)
            guard expandedIDs.contains(node.treeID) else { return }
            for child in node.treeChildren { appendVisible(child) }
        }
        appendVisible(root)
        guard let index = visibleIDs.firstIndex(of: targetID), index > 0 else { return nil }
        return visibleIDs[index - 1]
    }

    private func indentErased(_ ids: [AnyHashable]) {
        let typed = ids.compactMap { $0.base as? Node.ID }
        guard !typed.isEmpty else { return }
        onIndent(typed)
    }

    private func outdentErased(_ ids: [AnyHashable]) {
        let typed = ids.compactMap { $0.base as? Node.ID }
        guard !typed.isEmpty else { return }
        onOutdent(typed)
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
                hasChildren: hasChildren,
                isEditing: node.treeID == editingID,
                onRename: { title in onRename(node.treeID, title) },
                onCommitEditing: { title in
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        if let originalPreviousID = pendingCreatedPreviousIDs.removeValue(forKey: node.treeID) {
                            let previousID = previousVisibleID(before: node.treeID) ?? originalPreviousID
                            onDelete([node.treeID])
                            selection = previousID
                            selectedIDs = [previousID]
                        }
                    } else {
                        onRename(node.treeID, trimmed)
                        pendingCreatedPreviousIDs.removeValue(forKey: node.treeID)
                    }
                    if editingID == node.treeID { editingID = nil }
                },
                shouldFinishEditingOnFocusLoss: {
                    pointerInteractionTracker.shouldFinishEditingOnFocusLoss(for: AnyHashable(node.treeID))
                }
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
                gestureLayers: gestureLayers,
                children: children,
                contentCount: max(0, contentCount(node))
            )
        }
        return build(root, depth: 0)
    }
}
