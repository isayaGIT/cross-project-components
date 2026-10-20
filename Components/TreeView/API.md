# TreeView API contract

`TreeView<Node, RowContent>` is a reusable native macOS hierarchy component. The public SwiftUI-facing view is backed by AppKit's `NSOutlineView`.

## Ownership boundary

The component owns outline mechanics, stable native row wrappers, controlled expansion and selection synchronization, ancestor-preserving search, search-only expansion, row hit testing, and drag/drop proposal handling.

The host owns its domain model, persistence, mutations, move rules, row content, and application-specific visual treatment. The package does not depend on any consuming application's model or storage layer.

## Model contract

A host type conforms to `TreeNodeRepresentable`:

- `treeID` must be stable and unique within the tree.
- `treeTitle` is the default displayed title.
- `treeChildren` returns the node's children.

The supplied `root` is rendered as the visible root row. The component rebuilds a presentation snapshot from the current root during SwiftUI updates; keep IDs stable when updating the model.

## State and search

- `selection: Binding<Node.ID?>` is the selected node ID, or `nil`.
- `expandedIDs: Binding<Set<Node.ID>>` is the host's source of truth for saved expansion state.
- `searchText` filters by `searchableText`, which defaults to `treeTitle`.
- Search keeps each matching node and its ancestors visible. It expands the filtered path temporarily and does not write those temporary expansions into `expandedIDs`.
- Clear the query to restore the host-controlled expansion state.

## Row content and layout

- `rowContent` receives a `TreeRowContext` with the node, hierarchy depth, selected/expanded flags, and child presence.
- `rowHeight` returns the height for each node and depth; it defaults to 32 points.
- `disclosureCenterOffset` optionally positions the native disclosure control relative to the top of the row. By default it is centered.
- `interactiveHitTest` can reserve specific points in a row for embedded SwiftUI interactions (for example, an image scrubber). Points not reserved by this closure continue to use native row selection.

Keep app-specific icons, thumbnails, row metrics, and other presentation choices in the host's row builder rather than in this package.

## Keyboard creation and editing

- `onCreateSibling(currentID)` is called for Return/Enter only when no inline row editor is active. The host creates and returns the new node ID; pass `nil` to create at the top level when no row is selected.
- The component selects the newly created node and marks it as editing. Double-clicking a row also starts editing its title.
- `TreeRowContext.isEditing` lets the host render an inline editor. Call `onCommitEditing(title)` when the user presses Enter or when the editor loses focus. This commits the title and exits editing without creating another node. The row renderer should de-duplicate these triggers because Enter may also cause focus loss.
- If a newly created node is committed with an empty or whitespace-only title, the component removes it through the host's `onDelete` callback and restores selection to the row immediately before that node in the visible tree. Thus, leaving a newly created blank editor cancels that node; leaving an editor with a title keeps the node and ends editing. Deleting a node also selects the preceding visible row; for a multi-selection, the row before the first selected node is used. Empty renames of existing nodes are ignored.
- Creation is disabled while search filtering is active, because the filtered projection is not a safe basis for mutation placement.

## Editing and deletion

- Command-click uses native multi-selection; `selectedIDs` exposes the selected set while `selection` remains the primary/last selected ID.
- When the row editor is not active, Return/Enter creates a sibling after the last selected node in tree order. With no selection, the host receives `nil` and can append a top-level node. When editing, Enter commits the title instead.
- Command+Backspace opens one confirmation only when the selected subtrees contain content; plain Backspace is left to the system. The confirmation reports the total number of nodes including descendants and the total content-item count. Selected descendants of another selected node are deduplicated; the visible Root cannot be deleted.
- `contentCount` supplies the number of content items directly attached to each node. The component sums these values through each selected subtree before showing confirmation.
- `onDelete` receives only the selected subtree roots to delete. `onDeleteWithSelection`, when supplied, also receives the preceding visible row ID so the host can make deletion and its resulting selection one atomic undoable action. `onIndent` and `onOutdent` receive selected IDs in tree order.
- With the tree focused, Command+Z undoes the last committed tree change and Command+Shift+Z redoes it. Right-click provides Undo and Redo, Add node, Delete, Indent, and Outdent. Tab and Shift+Tab are displayed using native macOS menu key-equivalent symbols rather than being embedded in item titles. The host supplies `canUndo`, `canRedo`, `onUndo`, and `onRedo`; tree history and persistence remain the host's responsibility.

## Moving nodes

- `canMove(sourceID, targetID, placement)` is required and must be a pure validation callback. It must not mutate or persist the model.
- `onMove(sourceID, targetID, placement)` is called for an accepted drop; the host must perform the mutation and publish the updated root.
- `TreeMovePlacement` is package-owned and has `inside`, `before`, and `after` cases.
- The root cannot be dragged. A node cannot target itself or one of its descendants. Reordering is disabled while a search query is active.
- The host must additionally validate its own domain constraints, including any application-specific rules not represented by the generic tree hierarchy.

## Verification

The package tests cover filtered projections, ancestor retention, stable wrapper identity, search expansion restoration, drop placement and cycle prevention. Native controller tests exercise the actual `NSOutlineView` hierarchy, visible row counts, selection callbacks, expansion, and custom row heights.
