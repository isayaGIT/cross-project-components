import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Native AppKit implementation kept internal; the package's public API is TreeView.
final class TreeViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private let scrollView = NSScrollView()
    private let outlineView = TreeOutlineView()
    private var root: TreeNodeSnapshot?
    private var projection = TreeProjection(root: TreeNodeSnapshot(id: AnyHashable("empty"), title: "", searchableText: "", depth: 0, rowHeight: 32, disclosureCenterOffset: 16, content: AnyView(EmptyView()), interactiveHitTest: { _, _ in false }, gestureLayers: [], children: [], contentCount: 0), query: "", previousItems: [:])
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
    private var onDelete: ([AnyHashable], AnyHashable?) -> Void = { _, _ in }
    private var onIndent: ([AnyHashable]) -> Void = { _ in }
    private var onOutdent: ([AnyHashable]) -> Void = { _ in }
    private var canUndo = false
    private var canRedo = false
    private var onUndo: () -> Void = {}
    private var onRedo: () -> Void = {}
    private var contextMenuID: AnyHashable?
    private var onRowInteraction: (AnyHashable) -> Void = { _ in }
    private var onPointerInteraction: (AnyHashable?) -> Void = { _ in }
    private var onBeginEditing: (AnyHashable) -> Void = { _ in }
    private var mouseDownMonitor: Any?
    private var keyDownMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?
    private var windowResignKeyObserver: NSObjectProtocol?
    private var dragTokensByID: [AnyHashable: String] = [:]
    private var dragIDsByToken: [String: AnyHashable] = [:]
    private var isSynchronizingSelection = false
    private var isSynchronizingExpansion = false
    private var hasCompletedInitialConfiguration = false
    private var pendingHierarchyChange: (oldParentByID: [AnyHashable: AnyHashable?], nodeIDs: [AnyHashable])?

    deinit {
        removeInputMonitors()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        installInputMonitors()
    }

    override func viewWillDisappear() {
        removeInputMonitors()
        outlineView.cancelActivePointerSequence()
        super.viewWillDisappear()
    }

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
        outlineView.onRowMouseDown = { [weak self] id in self?.handleRowMouseDown(id) }
        outlineView.onGestureResolution = { [weak self] event in self?.resolveGesture(event) }
        outlineView.onDoubleClick = { [weak self] id in self?.onBeginEditing(id) }
        outlineView.onReturn = { [weak self] in self?.handleReturnKey() }
        outlineView.onDeleteKey = { [weak self] in self?.handleDeleteKey() }
        outlineView.onIndentKey = { [weak self] shift in self?.handleIndentKey(shift: shift) }
        outlineView.onUndo = { [weak self] in self?.onUndo() }
        outlineView.onRedo = { [weak self] in self?.onRedo() }
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
        onDelete newOnDelete: @escaping ([AnyHashable], AnyHashable?) -> Void,
        onIndent newOnIndent: @escaping ([AnyHashable]) -> Void,
        onOutdent newOnOutdent: @escaping ([AnyHashable]) -> Void,
        canUndo newCanUndo: Bool,
        canRedo newCanRedo: Bool,
        onUndo newOnUndo: @escaping () -> Void,
        onRedo newOnRedo: @escaping () -> Void,
        onRowInteraction newOnRowInteraction: @escaping (AnyHashable) -> Void,
        onPointerInteraction newOnPointerInteraction: @escaping (AnyHashable?) -> Void,
        onBeginEditing newOnBeginEditing: @escaping (AnyHashable) -> Void
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
        canUndo = newCanUndo
        canRedo = newCanRedo
        onUndo = newOnUndo
        onRedo = newOnRedo
        onRowInteraction = newOnRowInteraction
        onPointerInteraction = newOnPointerInteraction
        onBeginEditing = newOnBeginEditing
        installInputMonitors()
        outlineView.onRowMouseDown = { [weak self] id in self?.handleRowMouseDown(id) }
        outlineView.onGestureResolution = { [weak self] event in self?.resolveGesture(event) }
        outlineView.onDoubleClick = { [weak self] id in self?.onBeginEditing(id) }
        outlineView.onReturn = { [weak self] in self?.handleReturnKey() }
        outlineView.onDeleteKey = { [weak self] in self?.handleDeleteKey() }
        outlineView.onIndentKey = { [weak self] shift in self?.handleIndentKey(shift: shift) }
        outlineView.onUndo = { [weak self] in self?.onUndo() }
        outlineView.onRedo = { [weak self] in self?.onRedo() }
        outlineView.onContextMenu = { [weak self] id in self?.makeContextMenu(for: id) }

        let treeChanged = root == nil || projection.structureSignature != TreeStructureSignature(newRoot)
        let searchChanged = searchText != newSearchText
        let primarySelectionChanged = selectedID != newSelectedID
        let selectedChanged = primarySelectionChanged || (!newSelectedIDs.isEmpty && selectedIDs != newSelectedIDs)
        let expansionChanged = targetExpandedIDs != newExpandedIDs
        if !newSelectedIDs.isEmpty {
            selectedIDs = newSelectedIDs
        } else if primarySelectionChanged {
            selectedIDs = newSelectedID.map { [$0] } ?? []
        }
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
            showPendingHierarchyChangeIfNeeded()
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

    private func installInputMonitors() {
        if mouseDownMonitor == nil {
            mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
                guard let self else { return event }
                self.onPointerInteraction(self.rowID(at: event))
                return event
            }
        }
        if keyDownMonitor == nil {
            keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }

                // While an inline NSTextField is editing, Tab normally moves focus away
                // from the editor. That triggers the empty-new-node cleanup before the
                // tree can apply its hierarchy shortcut. Consume Tab/Shift+Tab here and
                // route it to the tree so the node remains in editing state.
                let modifiers = event.modifierFlags.intersection([.command, .control, .option])
                let isIndentKey = event.keyCode == 48 && modifiers.isEmpty
                let isShift = event.modifierFlags.contains(.shift)
                let isFieldEditor = event.window?.firstResponder is NSTextView
                    && (event.window?.firstResponder as? NSTextView)?.delegate is NSTextField
                if isIndentKey, isFieldEditor, event.window === self.outlineView.window {
                    self.handleIndentKey(shift: isShift)
                    return nil
                }

                self.onPointerInteraction(nil)
                return event
            }
        }
        if resignActiveObserver == nil {
            resignActiveObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: NSApp,
                queue: .main
            ) { [weak self] _ in
                self?.outlineView.cancelActivePointerSequence()
                self?.onPointerInteraction(nil)
            }
        }
        if windowResignKeyObserver == nil {
            windowResignKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self, notification.object as? NSWindow === self.outlineView.window else { return }
                self.outlineView.cancelActivePointerSequence()
                self.onPointerInteraction(nil)
            }
        }
    }

    private func removeInputMonitors() {
        if let mouseDownMonitor {
            NSEvent.removeMonitor(mouseDownMonitor)
            self.mouseDownMonitor = nil
        }
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }
        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
            self.resignActiveObserver = nil
        }
        if let windowResignKeyObserver {
            NotificationCenter.default.removeObserver(windowResignKeyObserver)
            self.windowResignKeyObserver = nil
        }
    }

    private func rowID(at event: NSEvent) -> AnyHashable? {
        guard let window = view.window, event.window === window else { return nil }
        let point = outlineView.convert(event.locationInWindow, from: nil)
        let row = outlineView.row(at: point)
        guard row >= 0, let item = outlineView.item(atRow: row) as? TreeOutlineItem else { return nil }
        return item.snapshot.id
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
        let firstSelectedRow = chosen.compactMap { outlineView.row(forItem: $0) }.filter { $0 >= 0 }.min()
        let previousVisibleID: AnyHashable? = firstSelectedRow.flatMap { firstRow in
            guard firstRow > 0,
                  let previousItem = outlineView.item(atRow: firstRow - 1) as? TreeOutlineItem else { return nil }
            return previousItem.snapshot.id
        }
        onDelete(roots.map { $0.snapshot.id }, previousVisibleID)
    }

    private func handleIndentKey(shift: Bool) {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let ids = selectedItemsInTreeOrder().map { $0.snapshot.id }.filter { $0 != root?.id }
        guard !ids.isEmpty, let root else { return }
        pendingHierarchyChange = (
            oldParentByID: Dictionary(uniqueKeysWithValues: ids.map { ($0, parentID(of: $0, in: root)) }),
            nodeIDs: ids
        )
        if shift { onOutdent(ids) } else { onIndent(ids) }
    }

    private func parentID(of targetID: AnyHashable, in node: TreeNodeSnapshot, parent: AnyHashable? = nil) -> AnyHashable? {
        if node.id == targetID { return parent }
        for child in node.children {
            if let found = parentID(of: targetID, in: child, parent: node.id) { return found }
        }
        return nil
    }

    private func resolveGesture(_ event: NSEvent) -> TreeGestureDecision? {
        guard event.window === outlineView.window else { return nil }
        let pointInOutline = outlineView.convert(event.locationInWindow, from: nil)
        let row = outlineView.row(at: pointInOutline)
        guard row >= 0,
              outlineView.item(atRow: row) is TreeOutlineItem,
              let cell = outlineView.view(atColumn: 0, row: row, makeIfNecessary: false) as? TreeOutlineCellView else { return nil }
        let pointInCell = cell.convert(event.locationInWindow, from: nil)
        return cell.resolveGesture(at: pointInCell, event: event)
    }

    private func handleRowMouseDown(_ id: AnyHashable) {
        onRowInteraction(id)
        showClickHighlight(for: id)
    }

    private func showPendingHierarchyChangeIfNeeded() {
        guard let pending = pendingHierarchyChange else { return }
        pendingHierarchyChange = nil
        guard let root else { return }
        for id in pending.nodeIDs {
            let oldParent = pending.oldParentByID[id] ?? nil
            guard let newParent = parentID(of: id, in: root), oldParent != newParent else { continue }
            showHierarchyHighlight(for: id)
            return
        }
    }

    private func showHierarchyHighlight(for id: AnyHashable) {
        guard let root,
              let parentID = parentID(of: id, in: root),
              rowIndex(for: id) != nil,
              rowIndex(for: parentID) != nil else { return }
        showRowGroupHighlight(for: [parentID, id])
    }

    private func showClickHighlight(for id: AnyHashable) {
        guard let root,
              let item = projection.allItemsByID[id],
              rowIndex(for: id) != nil else { return }

        var rowIDs = [id]
        if item.allChildren.isEmpty {
            // A leaf is best understood through its relationship with its parent.
            if let parent = parentID(of: id, in: root), rowIndex(for: parent) != nil {
                rowIDs.append(parent)
            }
        } else {
            // A node with descendants gets one enclosing outline around its visible
            // subtree. Hidden descendants stay hidden; clicking never expands the tree.
            func appendVisibleDescendants(of parent: TreeOutlineItem) {
                for child in parent.allChildren {
                    if rowIndex(for: child.snapshot.id) != nil {
                        rowIDs.append(child.snapshot.id)
                        appendVisibleDescendants(of: child)
                    }
                }
            }
            appendVisibleDescendants(of: item)
        }
        showRowGroupHighlight(for: rowIDs)
    }

    private func showRowGroupHighlight(for rowIDs: [AnyHashable]) {
        // A new interaction replaces any in-flight highlight so one clear region
        // remains visible instead of multiple nested or overlapping outlines.
        outlineView.subviews
            .compactMap { $0 as? TreeHierarchyChangeOverlay }
            .forEach { $0.removeFromSuperview() }

        let rowRects = rowIDs.compactMap { id -> NSRect? in
            guard let row = rowIndex(for: id) else { return nil }
            let rect = outlineView.rect(ofRow: row)
            return rect.isEmpty ? nil : rect
        }
        guard !rowRects.isEmpty else { return }

        let overlay = TreeHierarchyChangeOverlay(frame: outlineView.bounds)
        overlay.autoresizingMask = [.width, .height]
        outlineView.addSubview(overlay, positioned: .above, relativeTo: nil)

        // Union actual row rectangles after converting them to overlay coordinates.
        let convertedRects = rowRects.map { overlay.convert($0, from: outlineView) }
        guard let firstRect = convertedRects.first else {
            overlay.removeFromSuperview()
            return
        }
        let combinedRect = convertedRects.dropFirst().reduce(firstRect) { NSUnionRect($0, $1) }
        overlay.highlightRect = combinedRect.insetBy(dx: 3, dy: 2)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak overlay] in
            guard let overlay else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.62
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                overlay.animator().alphaValue = 0
            } completionHandler: {
                overlay.removeFromSuperview()
            }
        }
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
        let undoItem = NSMenuItem(title: "Undo", action: #selector(contextUndo), keyEquivalent: "z")
        undoItem.keyEquivalentModifierMask = [.command]
        undoItem.isEnabled = canUndo
        menu.addItem(undoItem)
        let redoItem = NSMenuItem(title: "Redo", action: #selector(contextRedo), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        redoItem.isEnabled = canRedo
        menu.addItem(redoItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Add node", action: #selector(contextAddNode), keyEquivalent: "")
        if id != root?.id {
            menu.addItem(.separator())
            let indentItem = NSMenuItem(title: "Indent", action: #selector(contextIndent), keyEquivalent: "\t")
            indentItem.keyEquivalentModifierMask = []
            menu.addItem(indentItem)
            let outdentItem = NSMenuItem(title: "Outdent", action: #selector(contextOutdent), keyEquivalent: "\t")
            outdentItem.keyEquivalentModifierMask = [.shift]
            menu.addItem(outdentItem)
            menu.addItem(.separator())
            let deleteItem = NSMenuItem(
                title: selectedItemsInTreeOrder().count > 1 ? "Delete selected nodes" : "Delete this node",
                action: #selector(contextDelete),
                keyEquivalent: ""
            )
            deleteItem.attributedTitle = NSAttributedString(
                string: deleteItem.title,
                attributes: [.foregroundColor: NSColor.systemRed]
            )
            menu.addItem(deleteItem)
        }
        for menuItem in menu.items where !menuItem.isSeparatorItem { menuItem.target = self }
        return menu
    }

    @objc private func contextAddNode() {
        let ids = selectedItemsInTreeOrder().map { $0.snapshot.id }
        _ = onCreateSibling(ids.last ?? contextMenuID)
    }
    @objc private func contextDelete() { handleDeleteKey() }
    @objc private func contextUndo() { if canUndo { onUndo() } }
    @objc private func contextRedo() { if canRedo { onRedo() } }
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
    var onGestureResolution: ((NSEvent) -> TreeGestureDecision?)?
    private(set) var activePointerSequence: TreeGestureDecision?
    private var pointerSequenceCancelled = false

    func cancelActivePointerSequence() {
        pointerSequenceCancelled = true
        activePointerSequence = nil
    }
    var onDoubleClick: ((AnyHashable) -> Void)?
    var onReturn: (() -> Void)?
    var onDeleteKey: (() -> Void)?
    var onIndentKey: ((Bool) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onContextMenu: ((AnyHashable) -> NSMenu?)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Preserve native text undo while an inline title field or other text editor owns focus.
        if window?.firstResponder is NSTextView { return super.performKeyEquivalent(with: event) }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        if event.keyCode == 6, modifiers.contains(.command), !modifiers.contains(.control), !modifiers.contains(.option) {
            if event.modifierFlags.contains(.shift) { onRedo?() } else { onUndo?() }
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        if event.keyCode == 6, modifiers.contains(.command), !modifiers.contains(.control), !modifiers.contains(.option) {
            if event.modifierFlags.contains(.shift) { onRedo?() } else { onUndo?() }
            return
        }
        if (event.keyCode == 36 || event.keyCode == 76), modifiers.isEmpty { onReturn?(); return }
        if event.keyCode == 51,
           modifiers.contains(.command),
           !modifiers.contains(.control),
           !modifiers.contains(.option) {
            onDeleteKey?()
            return
        }
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
        activePointerSequence = onGestureResolution?(event)
            ?? TreeGestureDecision(route: .treeNative, owner: .nativeTree)
        pointerSequenceCancelled = false

        // Both cell hit-testing and this event path use the same resolver. Normally AppKit targets
        // the hosted control directly. If the outline receives this event instead, retain embedded
        // ownership so later drag/up events cannot leak into native Tree behavior.
        if activePointerSequence?.route == .embeddedView { return }

        super.mouseDown(with: event)
        guard !pointerSequenceCancelled else { return }
        if let id {
            onRowMouseDown?(id)
            if event.clickCount == 2 { onDoubleClick?(id) }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !pointerSequenceCancelled, activePointerSequence?.route != .embeddedView else { return }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        guard !pointerSequenceCancelled else { activePointerSequence = nil; return }
        if activePointerSequence?.route == .embeddedView {
            activePointerSequence = nil
            return
        }
        super.mouseUp(with: event)
        activePointerSequence = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        activePointerSequence = onGestureResolution?(event)
            ?? TreeGestureDecision(route: .treeNative, owner: .nativeTree)
        pointerSequenceCancelled = false
        guard activePointerSequence?.route != .embeddedView else { return }
        super.rightMouseDown(with: event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        guard !pointerSequenceCancelled, activePointerSequence?.route != .embeddedView else { return }
        super.rightMouseDragged(with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        guard !pointerSequenceCancelled else { activePointerSequence = nil; return }
        if activePointerSequence?.route == .embeddedView {
            activePointerSequence = nil
            return
        }
        super.rightMouseUp(with: event)
        activePointerSequence = nil
    }

    override func otherMouseDown(with event: NSEvent) {
        activePointerSequence = onGestureResolution?(event)
            ?? TreeGestureDecision(route: .treeNative, owner: .nativeTree)
        pointerSequenceCancelled = false
        guard activePointerSequence?.route != .embeddedView else { return }
        super.otherMouseDown(with: event)
    }

    override func otherMouseDragged(with event: NSEvent) {
        guard !pointerSequenceCancelled, activePointerSequence?.route != .embeddedView else { return }
        super.otherMouseDragged(with: event)
    }

    override func otherMouseUp(with event: NSEvent) {
        guard !pointerSequenceCancelled else { activePointerSequence = nil; return }
        if activePointerSequence?.route == .embeddedView {
            activePointerSequence = nil
            return
        }
        super.otherMouseUp(with: event)
        activePointerSequence = nil
    }
}

private final class TreeHierarchyChangeOverlay: NSView {
    // Match the outline view's coordinate orientation so row geometry remains intuitive.
    override var isFlipped: Bool { superview?.isFlipped ?? true }

    var highlightRect: NSRect = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard !highlightRect.isEmpty else { return }
        NSColor.controlAccentColor.withAlphaComponent(0.9).setStroke()
        let path = NSBezierPath(roundedRect: highlightRect, xRadius: 7, yRadius: 7)
        path.lineWidth = 1.5
        path.stroke()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
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
    private var snapshot: TreeNodeSnapshot?

    var hostSize: CGSize { host?.bounds.size ?? .zero }

    func convertToTopLeadingHostPoint(_ pointInCell: CGPoint) -> CGPoint {
        guard let host else { return .zero }
        let point = host.convert(pointInCell, from: self)
        let size = host.bounds.size
        return CGPoint(x: point.x, y: host.isFlipped ? point.y : size.height - point.y)
    }

    // Hit testing also runs during cursor/tracking updates, when NSApp.currentEvent may be
    // a non-mouse event. Only callers handling an actual pointer event should supply it.
    func resolveGesture(at pointInCell: CGPoint, event: NSEvent? = nil) -> TreeGestureDecision? {
        guard let snapshot else { return nil }
        let kind: TreeGestureKind
        switch event?.type {
        case .rightMouseDown, .rightMouseDragged, .rightMouseUp: kind = .secondaryPointer
        case .otherMouseDown, .otherMouseDragged, .otherMouseUp: kind = .otherPointer
        default: kind = .primaryPointer
        }
        let context = TreeGestureHitTestContext(
            nodeID: snapshot.id,
            point: convertToTopLeadingHostPoint(pointInCell),
            size: hostSize,
            kind: kind,
            clickCount: event?.clickCount ?? 1,
            modifierFlags: event?.modifierFlags.rawValue ?? 0
        )
        return snapshot.resolveGesture(context)
    }

    func configure(item: TreeOutlineItem) {
        subviews.forEach { $0.removeFromSuperview() }
        let host = NSHostingView(rootView: item.snapshot.content)
        host.translatesAutoresizingMaskIntoConstraints = false
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        self.host = host
        self.snapshot = item.snapshot
        addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // NSView.hitTest(_:) already supplies a point in this cell's coordinate space.
        // Convert that local point into the hosting view instead of interpreting it as
        // a point in the row view; the latter shifts the reserved region by the cell frame.
        guard let host else { return nil }
        let pointInHost = host.convert(point, from: self)

        // Hit testing is location-only. Do not inspect NSApp.currentEvent here: AppKit also
        // calls hitTest during tracking/cursor updates, where NSEvent.clickCount is invalid.
        // Native mouse-down arbitration supplies its concrete NSEvent separately.
        guard resolveGesture(at: point)?.route == .embeddedView else { return nil }
        return host.hitTest(pointInHost) ?? host
    }
}
