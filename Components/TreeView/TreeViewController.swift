import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Native AppKit implementation kept internal; the package's public API is TreeView.
final class TreeViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private let scrollView = NSScrollView()
    private let outlineView = TreeOutlineView()
    private var root: TreeNodeSnapshot?
    private var projection = TreeProjection(root: TreeNodeSnapshot(id: AnyHashable("empty"), title: "", searchableText: "", depth: 0, rowHeight: 32, disclosureCenterOffset: 16, content: AnyView(EmptyView()), interactiveHitTest: { _, _ in false }, children: [], contentCount: 0), query: "", previousItems: [:])
    private var searchText = ""
    private var selectedID: AnyHashable?
    private var selectedIDs: Set<AnyHashable> = []
    private var targetExpandedIDs: Set<AnyHashable> = []
    private var canMove: (AnyHashable, AnyHashable, TreeMovePlacement) -> Bool = { _, _, _ in false }
    private var onSelect: (AnyHashable?) -> Void = { _ in }
    private var onToggleExpanded: (AnyHashable) -> Void = { _ in }
    private var onMove: (AnyHashable, AnyHashable, TreeMovePlacement) -> Void = { _, _, _ in }
    private var onCreateSibling: (AnyHashable?) -> AnyHashable? = { _ in nil }
    private var onSelectMultiple: (Set<AnyHashable>) -> Void = { _ in }
    private var onDelete: ([AnyHashable]) -> Void = { _ in }
    private var onIndent: ([AnyHashable]) -> Void = { _ in }
    private var onOutdent: ([AnyHashable]) -> Void = { _ in }
    private var contextMenuID: AnyHashable?
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
        outlineView.allowsMultipleSelection = true
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
        outlineView.onDeleteKey = { [weak self] in self?.handleDeleteKey() }
        outlineView.onIndentKey = { [weak self] shift in self?.handleIndentKey(shift: shift) }
        outlineView.onContextMenu = { [weak self] id in self?.makeContextMenu(for: id) }
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
        selectedIDs newSelectedIDs: Set<AnyHashable>,
        expandedIDs newExpandedIDs: Set<AnyHashable>,
        searchText newSearchText: String,
        canMove newCanMove: @escaping (AnyHashable, AnyHashable, TreeMovePlacement) -> Bool,
        onSelect newOnSelect: @escaping (AnyHashable?) -> Void,
        onToggleExpanded newOnToggleExpanded: @escaping (AnyHashable) -> Void,
        onMove newOnMove: @escaping (AnyHashable, AnyHashable, TreeMovePlacement) -> Void,
        onCreateSibling newOnCreateSibling: @escaping (AnyHashable?) -> AnyHashable?,
        onSelectMultiple newOnSelectMultiple: @escaping (Set<AnyHashable>) -> Void,
        onDelete newOnDelete: @escaping ([AnyHashable]) -> Void,
        onIndent newOnIndent: @escaping ([AnyHashable]) -> Void,
        onOutdent newOnOutdent: @escaping ([AnyHashable]) -> Void,
        onRowInteraction newOnRowInteraction: @escaping (AnyHashable) -> Void
    ) {
        canMove = newCanMove
        onSelect = newOnSelect
        onToggleExpanded = newOnToggleExpanded
        onMove = newOnMove
        onCreateSibling = newOnCreateSibling
        onSelectMultiple = newOnSelectMultiple
        onDelete = newOnDelete
        onIndent = newOnIndent
        onOutdent = newOnOutdent
        onRowInteraction = newOnRowInteraction
        outlineView.onRowMouseDown = { [weak self] id in self?.onRowInteraction(id) }
        outlineView.onReturn = { [weak self] in self?.handleReturnKey() }
        outlineView.onDeleteKey = { [weak self] in self?.handleDeleteKey() }
        outlineView.onIndentKey = { [weak self] shift in self?.handleIndentKey(shift: shift) }
        outlineView.onContextMenu = { [weak self] id in self?.makeContextMenu(for: id) }

        let treeChanged = root == nil || projection.structureSignature != TreeStructureSignature(newRoot)
        let searchChanged = searchText != newSearchText
        let selectedChanged = selectedID != newSelectedID || selectedIDs != newSelectedIDs
        let expansionChanged = targetExpandedIDs != newExpandedIDs
        selectedID = newSelectedID
        selectedIDs = newSelectedIDs.isEmpty && newSelectedID != nil ? [newSelectedID!] : newSelectedIDs
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
        let currentIDs = selectedItemsInTreeOrder().map { $0.snapshot.id }
        let current = currentIDs.last
        _ = onCreateSibling(current)
    }

    private func selectedItemsInTreeOrder() -> [TreeOutlineItem] {
        (0..<outlineView.numberOfRows).compactMap { row in
            guard outlineView.isRowSelected(row) else { return nil }
            return outlineView.item(atRow: row) as? TreeOutlineItem
        }
    }

    private func handleDeleteKey() {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let chosen = selectedItemsInTreeOrder().filter { $0.snapshot.id != root?.id }
        guard !chosen.isEmpty else { return }
        let roots = chosen.filter { item in
            !chosen.contains { other in other.snapshot.id != item.snapshot.id && projection.isDescendant(item.snapshot.id, of: other.snapshot.id) }
        }
        let nodeCount = roots.reduce(0) { $0 + $1.snapshot.subtreeNodeCount }
        let contentCount = roots.reduce(0) { $0 + $1.snapshot.subtreeContentCount }
        if contentCount > 0 {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Delete \(nodeCount) node\(nodeCount == 1 ? "" : "s")?"
            alert.informativeText = "This will delete \(nodeCount) node\(nodeCount == 1 ? "" : "s"), including all descendants, and permanently remove \(contentCount) content item\(contentCount == 1 ? "" : "s"). This cannot be undone."
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        onDelete(roots.map { $0.snapshot.id })
    }

    private func handleIndentKey(shift: Bool) {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let ids = selectedItemsInTreeOrder().map { $0.snapshot.id }.filter { $0 != root?.id }
        guard !ids.isEmpty else { return }
        if shift { onOutdent(ids) } else { onIndent(ids) }
    }

    private func makeContextMenu(for id: AnyHashable) -> NSMenu? {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let item = projection.allItemsByID[id] else { return nil }
        if !selectedIDs.contains(id) {
            selectedIDs = [id]
            selectedID = id
            outlineView.selectRowIndexes(IndexSet(integer: outlineView.row(forItem: item)), byExtendingSelection: false)
            onSelect(id)
            onSelectMultiple([id])
        }
        contextMenuID = id
        let menu = NSMenu()
        menu.addItem(withTitle: "Add node", action: #selector(contextAddNode), keyEquivalent: "")
        if id != root?.id {
            menu.addItem(.separator())
            menu.addItem(withTitle: "Indent (Tab)", action: #selector(contextIndent), keyEquivalent: "")
            menu.addItem(withTitle: "Outdent (Shift Tab)", action: #selector(contextOutdent), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: selectedItemsInTreeOrder().count > 1 ? "Delete selected nodes" : "Delete this node", action: #selector(contextDelete), keyEquivalent: "")
        }
        for menuItem in menu.items where !menuItem.isSeparatorItem { menuItem.target = self }
        return menu
    }

    @objc private func contextAddNode() {
        let ids = selectedItemsInTreeOrder().map { $0.snapshot.id }
        _ = onCreateSibling(ids.last ?? contextMenuID)
    }
    @objc private func contextDelete() { handleDeleteKey() }
    @objc private func contextIndent() { handleIndentKey(shift: false) }
    @objc private func contextOutdent() { handleIndentKey(shift: true) }

    private func synchronizeSelection(_ id: AnyHashable?) {
        let previous = isSynchronizingSelection
        isSynchronizingSelection = true
        defer { isSynchronizingSelection = previous }
        guard rowIndex(for: id) != nil else { outlineView.deselectAll(nil); return }
        let indexes = IndexSet((0..<outlineView.numberOfRows).filter { rowIndex in
            guard let item = outlineView.item(atRow: rowIndex) as? TreeOutlineItem else { return false }
            return selectedIDs.contains(item.snapshot.id)
        })
        if indexes.isEmpty { outlineView.deselectAll(nil) }
        else if outlineView.selectedRowIndexes != indexes { outlineView.selectRowIndexes(indexes, byExtendingSelection: false) }
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
        let items = selectedItemsInTreeOrder()
        let ids = Set(items.map { $0.snapshot.id })
        selectedIDs = ids
        onSelectMultiple(ids)
        if let item = items.last {
            selectedID = item.snapshot.id
            onSelect(item.snapshot.id)
        } else {
            selectedID = nil
            onSelect(nil)
        }
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
    var onDeleteKey: (() -> Void)?
    var onIndentKey: ((Bool) -> Void)?
    var onContextMenu: ((AnyHashable) -> NSMenu?)?

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        if (event.keyCode == 36 || event.keyCode == 76), modifiers.isEmpty { onReturn?(); return }
        if (event.keyCode == 51 || event.keyCode == 117), modifiers.isEmpty { onDeleteKey?(); return }
        if event.keyCode == 48, modifiers.isEmpty { onIndentKey?(event.modifierFlags.contains(.shift)); return }
        super.keyDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        guard row >= 0, let item = item(atRow: row) as? TreeOutlineItem else { return super.menu(for: event) }
        return onContextMenu?(item.snapshot.id) ?? super.menu(for: event)
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
