import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Native AppKit implementation kept internal; the package's public API is TreeView.
final class TreeViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private let scrollView = NSScrollView()
    private let outlineView = TreeOutlineView()
    private var root: TreeNodeSnapshot?
    private var projection = TreeProjection(root: TreeNodeSnapshot(id: AnyHashable("empty"), title: "", searchableText: "", depth: 0, rowHeight: 32, disclosureCenterOffset: 16, content: AnyView(EmptyView()), interactiveHitTest: { _, _ in false }, children: []), query: "", previousItems: [:])
    private var searchText = ""
    private var selectedID: AnyHashable?
    private var targetExpandedIDs: Set<AnyHashable> = []
    private var canMove: (AnyHashable, AnyHashable, TreeMovePlacement) -> Bool = { _, _, _ in false }
    private var onSelect: (AnyHashable?) -> Void = { _ in }
    private var onToggleExpanded: (AnyHashable) -> Void = { _ in }
    private var onMove: (AnyHashable, AnyHashable, TreeMovePlacement) -> Void = { _, _, _ in }
    private var onCreateSibling: (AnyHashable?) -> AnyHashable? = { _ in nil }
    private var onRowInteraction: (AnyHashable) -> Void = { _ in }
    private var dragTokensByID: [AnyHashable: String] = [:]
    private var dragIDsByToken: [String: AnyHashable] = [:]
    private var isSynchronizingSelection = false
    private var isSynchronizingExpansion = false
    private var hasCompletedInitialConfiguration = false

    override func loadView() {
        let container = NSView(frame: .zero)
        container.translatesAutoresizingMaskIntoConstraints = false
        view = container
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        outlineView.translatesAutoresizingMaskIntoConstraints = false
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.headerView = nil
        outlineView.allowsMultipleSelection = false
        outlineView.allowsEmptySelection = true
        outlineView.selectionHighlightStyle = .regular
        outlineView.style = .sourceList
        outlineView.indentationPerLevel = 14
        outlineView.rowHeight = 32
        outlineView.usesAutomaticRowHeights = false
        outlineView.intercellSpacing = NSSize(width: 0, height: 0)
        outlineView.gridStyleMask = []
        outlineView.backgroundColor = .clear
        outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TreeNode"))
        column.resizingMask = .autoresizingMask
        column.width = 270
        column.minWidth = 240
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.registerForDraggedTypes([.string, NSPasteboard.PasteboardType(UTType.plainText.identifier)])
        outlineView.onRowMouseDown = { [weak self] id in self?.onRowInteraction(id) }
        outlineView.onReturn = { [weak self] in self?.handleReturnKey() }
        scrollView.documentView = outlineView
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    func update(
        root newRoot: TreeNodeSnapshot,
        selectedID newSelectedID: AnyHashable?,
        expandedIDs newExpandedIDs: Set<AnyHashable>,
        searchText newSearchText: String,
        canMove newCanMove: @escaping (AnyHashable, AnyHashable, TreeMovePlacement) -> Bool,
        onSelect newOnSelect: @escaping (AnyHashable?) -> Void,
        onToggleExpanded newOnToggleExpanded: @escaping (AnyHashable) -> Void,
        onMove newOnMove: @escaping (AnyHashable, AnyHashable, TreeMovePlacement) -> Void,
        onCreateSibling newOnCreateSibling: @escaping (AnyHashable?) -> AnyHashable?,
        onRowInteraction newOnRowInteraction: @escaping (AnyHashable) -> Void
    ) {
        canMove = newCanMove
        onSelect = newOnSelect
        onToggleExpanded = newOnToggleExpanded
        onMove = newOnMove
        onCreateSibling = newOnCreateSibling
        onRowInteraction = newOnRowInteraction
        outlineView.onRowMouseDown = { [weak self] id in self?.onRowInteraction(id) }
        outlineView.onReturn = { [weak self] in self?.handleReturnKey() }

        let treeChanged = root == nil || projection.structureSignature != TreeStructureSignature(newRoot)
        let searchChanged = searchText != newSearchText
        let selectedChanged = selectedID != newSelectedID
        let expansionChanged = targetExpandedIDs != newExpandedIDs
        selectedID = newSelectedID
        searchText = newSearchText

        let previousScrollOrigin = scrollView.contentView.bounds.origin
        projection = TreeProjection(root: newRoot, query: newSearchText, previousItems: projection.allItemsByID)
        root = newRoot
        dragTokensByID = dragTokensByID.filter { projection.allItemsByID[$0.key] != nil }
        dragIDsByToken = dragIDsByToken.filter { projection.allItemsByID[$0.value] != nil }

        if treeChanged || searchChanged || !hasCompletedInitialConfiguration {
            isSynchronizingSelection = true
            outlineView.reloadData()
            let desiredExpansion = TreeProjection.expansionIDs(for: projection.rootItems, query: newSearchText, savedIDs: newExpandedIDs)
            applyFullExpansionState(desiredExpansion)
            targetExpandedIDs = newExpandedIDs
            synchronizeSelection(newSelectedID)
            isSynchronizingSelection = false
            view.layoutSubtreeIfNeeded()
            if hasCompletedInitialConfiguration {
                scrollView.contentView.scroll(to: previousScrollOrigin)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            } else if let row = rowIndex(for: newSelectedID) {
                outlineView.scrollRowToVisible(row)
            }
            hasCompletedInitialConfiguration = true
        } else {
            // Refresh row content (e.g. external selection flags or host metadata) without
            // rebuilding the native hierarchy, which keeps scroll and expansion stable.
            if outlineView.numberOfRows > 0 {
                outlineView.reloadData(forRowIndexes: IndexSet(integersIn: 0..<outlineView.numberOfRows), columnIndexes: IndexSet(integer: 0))
            }
            if expansionChanged {
                applyExpansionChanges(from: targetExpandedIDs, to: newExpandedIDs)
                targetExpandedIDs = newExpandedIDs
            }
            if selectedChanged { synchronizeSelection(newSelectedID) }
        }
    }

    private func applyFullExpansionState(_ targetIDs: Set<AnyHashable>) {
        let previous = isSynchronizingExpansion
        isSynchronizingExpansion = true
        defer { isSynchronizingExpansion = previous }
        let stale = projection.itemsByID.values
            .filter { !targetIDs.contains($0.snapshot.id) && outlineView.isItemExpanded($0) }
            .sorted { projection.depth(of: $0.snapshot.id) > projection.depth(of: $1.snapshot.id) }
        for item in stale { outlineView.collapseItem(item) }
        let wanted = targetIDs.compactMap { projection.itemsByID[$0] }
            .filter { !$0.children.isEmpty }
            .sorted { projection.depth(of: $0.snapshot.id) < projection.depth(of: $1.snapshot.id) }
        for item in wanted where !outlineView.isItemExpanded(item) { outlineView.expandItem(item) }
    }

    private func applyExpansionChanges(from oldIDs: Set<AnyHashable>, to newIDs: Set<AnyHashable>) {
        let previous = isSynchronizingExpansion
        isSynchronizingExpansion = true
        defer { isSynchronizingExpansion = previous }
        for id in oldIDs.subtracting(newIDs).sorted(by: { projection.depth(of: $0) > projection.depth(of: $1) }) {
            if let item = projection.itemsByID[id], outlineView.isItemExpanded(item) { outlineView.collapseItem(item) }
        }
        for id in newIDs.subtracting(oldIDs).sorted(by: { projection.depth(of: $0) < projection.depth(of: $1) }) {
            if let item = projection.itemsByID[id], !item.children.isEmpty, !outlineView.isItemExpanded(item) { outlineView.expandItem(item) }
        }
    }

    private func handleReturnKey() {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let current = outlineView.selectedRow >= 0
            ? (outlineView.item(atRow: outlineView.selectedRow) as? TreeOutlineItem)?.snapshot.id
            : nil
        _ = onCreateSibling(current)
    }

    private func synchronizeSelection(_ id: AnyHashable?) {
        let previous = isSynchronizingSelection
        isSynchronizingSelection = true
        defer { isSynchronizingSelection = previous }
        guard let row = rowIndex(for: id) else { outlineView.deselectAll(nil); return }
        if outlineView.selectedRow != row { outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
    }

    private func rowIndex(for id: AnyHashable?) -> Int? {
        guard let id, let item = projection.itemsByID[id] else { return nil }
        let row = outlineView.row(forItem: item)
        return row >= 0 ? row : nil
    }

    // MARK: NSOutlineViewDataSource
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? TreeOutlineItem)?.children.count ?? projection.rootItems.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? TreeOutlineItem { return item.children[index] }
        return projection.rootItems[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? TreeOutlineItem)?.children.isEmpty == false
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        (item as? TreeOutlineItem)?.snapshot.title
    }

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> (any NSPasteboardWriting)? {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let item = item as? TreeOutlineItem,
              item.snapshot.id != root?.id else { return nil }
        let pasteboard = NSPasteboardItem()
        let id = item.snapshot.id
        let token = dragTokensByID[id] ?? UUID().uuidString
        dragTokensByID[id] = token
        dragIDsByToken[token] = id
        pasteboard.setString(token, forType: .string)
        pasteboard.setString(token, forType: NSPasteboard.PasteboardType(UTType.plainText.identifier))
        return pasteboard
    }

    // MARK: NSOutlineViewDelegate
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let item = item as? TreeOutlineItem else { return nil }
        let cell = TreeOutlineCellView(frame: .zero)
        cell.configure(item: item)
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        TreeOutlineRowView(frame: .zero)
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        (item as? TreeOutlineItem)?.snapshot.rowHeight ?? 32
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard !isSynchronizingExpansion, let item = notification.userInfo?["NSObject"] as? TreeOutlineItem else { return }
        onToggleExpanded(item.snapshot.id)
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard !isSynchronizingExpansion, let item = notification.userInfo?["NSObject"] as? TreeOutlineItem else { return }
        onToggleExpanded(item.snapshot.id)
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isSynchronizingSelection else { return }
        let row = outlineView.selectedRow
        guard row >= 0, let item = outlineView.item(atRow: row) as? TreeOutlineItem, item.snapshot.id != selectedID else { return }
        selectedID = item.snapshot.id
        onSelect(item.snapshot.id)
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let source = draggedID(from: info.draggingPasteboard),
              let plan = TreeDropPlan.make(proposedItem: proposedItem, childIndex: index),
              source != root?.id, source != plan.targetID,
              !projection.isDescendant(plan.targetID, of: source),
              canMove(source, plan.targetID, plan.placement) else {
            outlineView.setDropItem(nil, dropChildIndex: NSOutlineViewDropOnItemIndex)
            return []
        }
        outlineView.setDropItem(plan.proposedItem, dropChildIndex: plan.proposedChildIndex)
        return .move
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let source = draggedID(from: info.draggingPasteboard),
              let plan = TreeDropPlan.make(proposedItem: item, childIndex: index),
              source != root?.id, source != plan.targetID,
              !projection.isDescendant(plan.targetID, of: source),
              canMove(source, plan.targetID, plan.placement) else { return false }
        onMove(source, plan.targetID, plan.placement)
        return true
    }

    private func draggedID(from pasteboard: NSPasteboard) -> AnyHashable? {
        guard let token = pasteboard.string(forType: .string)
            ?? pasteboard.string(forType: NSPasteboard.PasteboardType(UTType.plainText.identifier)) else { return nil }
        return dragIDsByToken[token]
    }
}

private final class TreeOutlineView: NSOutlineView {
    var onRowMouseDown: ((AnyHashable) -> Void)?
    var onReturn: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if (event.keyCode == 36 || event.keyCode == 76), event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            onReturn?()
            return
        }
        super.keyDown(with: event)
    }

    override func frameOfOutlineCell(atRow row: Int) -> NSRect {
        let frame = super.frameOfOutlineCell(atRow: row)
        guard row >= 0, let item = item(atRow: row) as? TreeOutlineItem, !frame.isEmpty else { return frame }
        let offset = item.snapshot.disclosureCenterOffset
        guard abs(offset - item.snapshot.rowHeight / 2) > 0.01 else { return frame }
        var adjusted = frame
        adjusted.origin.y = rect(ofRow: row).minY + offset - adjusted.height / 2
        return adjusted
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        let id = row >= 0 ? (item(atRow: row) as? TreeOutlineItem)?.snapshot.id : nil
        super.mouseDown(with: event)
        if let id { onRowMouseDown?(id) }
    }
}

private final class TreeOutlineRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 6, yRadius: 6).fill()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}

private final class TreeOutlineCellView: NSView {
    private var host: NSHostingView<AnyView>?
    private var interactiveHitTest: ((CGPoint, CGSize) -> Bool)?

    func configure(item: TreeOutlineItem) {
        subviews.forEach { $0.removeFromSuperview() }
        let host = NSHostingView(rootView: item.snapshot.content)
        host.translatesAutoresizingMaskIntoConstraints = false
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        self.host = host
        interactiveHitTest = item.snapshot.interactiveHitTest
        addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let pointInCell = convert(point, from: superview)
        guard let host, interactiveHitTest?(CGPoint(x: pointInCell.x, y: pointInCell.y), bounds.size) == true else { return nil }
        return host.hitTest(pointInCell) ?? host
    }
}
