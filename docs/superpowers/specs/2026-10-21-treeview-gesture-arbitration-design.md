# TreeView Gesture Arbitration Design

Date: 2026-10-21
Status: Approved by user; implementation in progress
Repositories: `isayaGIT/cross-project-components`, `isayaGIT/Project-Knowledge-Navigator`

## 1. Problem and current state

The shared TreeView currently has a public `TreeGestureLayer` protocol with a priority and a boolean `claims(_:)` hit-test. Layers are evaluated only to decide whether an embedded row control should receive a pointer hit. When no embedded layer claims the point, the rest of the gesture pipeline remains split across AppKit behavior and callbacks:

- `TreeOutlineView.mouseDown` handles the embedded-control guard, then delegates to `NSOutlineView`, then invokes row-interaction and double-click callbacks.
- AppKit selection and drag initiation are driven by the native outline view.
- Expansion/collapse is observed through outline-view delegate callbacks.
- The row cell's `hitTest` separately consults the same claim check.
- Keyboard shortcuts are handled through `keyDown` and local event monitors; these are commands/input routing, not pointer-gesture arbitration.
- The host application currently registers only `ProjectFilmstripGestureLayer`.

The result is a useful first layer API, but not yet one coherent gesture ownership model.

## 2. Goals

1. Route each relevant pointer gesture through one deterministic arbitration point before it can trigger Tree behavior.
2. Resolve by descending priority; registration order breaks ties.
3. Assign exactly one owner for a pointer sequence and keep that owner until completion or cancellation.
4. Prevent a gesture already claimed by an embedded control or a custom layer from also triggering selection, title editing, disclosure, or Tree drag behavior.
5. Preserve AppKit's native text editing, selection, disclosure, and drag-and-drop wherever the native implementation is the correct executor.
6. Keep the API reusable across host applications and source-compatible with existing `interactiveHitTest` call sites during migration.
7. Keep arbitration observable and debuggable: context, winning layer/route, and cancellation reason should be inspectable during development without adding permanent UI noise.

## 3. Non-goals

- Replacing `NSOutlineView` or implementing a custom drag-and-drop engine.
- Rewriting keyboard shortcuts as pointer gestures. Keyboard commands remain a separate command-routing path and must respect native text-editor focus.
- Adding a generic gesture DSL, gesture graph editor, plugin registry, or animation framework.
- Requiring a test target inside the component library solely for this change; validate through the host application's existing tests, build, and focused manual interaction checks.

## 4. Proposed architecture

### 4.1 One resolver, explicit routes

Introduce one internal resolver that receives an immutable pointer context and evaluates the registered gesture layers in priority order. The result must identify the winning owner/route rather than returning only a boolean. The resolver must be used by both the cell hit-testing path and the outline view's pointer-event path, so those paths cannot disagree about whether a location belongs to an embedded control.

The decision model should distinguish at least:

- **Layer-owned**: a registered custom layer owns the sequence and receives the events it needs.
- **Embedded-view-owned**: an interactive hosted row control, such as the filmstrip, receives the sequence through AppKit's normal view hit-testing/dispatch.
- **Tree-native**: no higher-priority layer claims the input; preserve native Tree selection, disclosure, editing trigger, and drag/drop behavior.
- **Unclaimed/outside**: the event is not associated with a Tree row or no applicable route exists.

The default Tree behavior is the final fallback, not an independent parallel handler.

### 4.2 Layer contract

Evolve the current boolean-only protocol into a small claim/resolution contract. A claim must identify both the winning layer and its delivery route: forward the sequence to the embedded row view, or execute a Tree-owned action through the central dispatcher. This allows host controls and built-in Tree behavior to share arbitration without forcing every layer to become a custom AppKit view. The contract should provide:

- A stable priority.
- A claim/resolution function receiving node ID, row-content point and size, pointer kind, click count, modifier flags, and gesture phase/type as needed.
- An explicit owner/route in the resolution result.
- A defined event lifecycle for the winner: begin, movement/update, end, and cancellation where applicable.
- A clear rule that a lower-priority layer is not reconsidered after an owner has been selected for that sequence.

Prefer a small set of explicit types over a generic gesture framework. Existing embedded controls should continue to receive native AppKit events when that is the selected route.

### 4.3 Internal Tree layers

Represent Tree-owned pointer behavior in the same arbitration vocabulary, even if the actual executor remains AppKit. Before numeric layer arbitration, AppKit responder/focus ownership acts as a hard preflight gate: an active native text editor and its field editor keep their normal input and text-selection events. Those events are not modeled as an ordinary Tree layer because the Tree must not intercept them. After that gate, the conceptual ordering is:

1. Explicit host-registered embedded/custom interactions, including the filmstrip.
2. Node-specific Tree interactions, such as a title double-click to begin editing.
3. Tree structural interactions, including disclosure and row selection.
4. Default native outline behavior, including drag initiation and drop handling when applicable.

The ordering must be reconciled with AppKit's actual event targeting. The implementation must not swallow events needed by a text field or field editor.

Disclosure hit regions require special care. If AppKit handles the disclosure triangle before the normal row path, the resolver must preserve that native behavior while ensuring an embedded layer cannot claim the disclosure region accidentally.

### 4.4 Owner lifecycle

Resolve ownership at pointer-down. Keep the selected owner for that sequence until mouse-up, cancellation, window deactivation, or view teardown. Drag updates and the terminal event must not be re-resolved against changing pointer positions; otherwise a drag that begins in the filmstrip could leak into Tree selection or hierarchy drag after crossing a row boundary.

Use AppKit's existing event tracking and drag mechanisms where possible. Do not build a second polling/tracking loop unless the current event path demonstrably cannot maintain ownership. Clear ownership defensively on cancellation, window resign-active, and controller teardown.

### 4.5 Compatibility

- Keep the existing `gestureLayers:` initializer argument.
- Keep `interactiveHitTest` source-compatible as a deprecated/legacy fallback during migration, with documented precedence below explicit layers.
- Avoid changing node model/persistence APIs.
- Migrate the Knowledge Navigator filmstrip first, then move node double-click and other Tree-owned pointer decisions to the resolver.
- Keyboard shortcuts, context-menu commands, undo/redo, and editing-focus management remain on their current command/responder paths unless inspection reveals a direct pointer arbitration conflict.

## 5. Event flow

1. AppKit delivers a pointer-down to the Tree or a row subview.
2. The shared resolver constructs the canonical context and chooses one route once.
3. The chosen owner receives the initial event. If it is an embedded view, native hit-testing/dispatch remains responsible for that control. If it is Tree-native, the existing outline-view behavior executes.
4. The same owner retains the sequence through drag/update and completion; no lower layer is allowed to reinterpret it.
5. The resolver clears ownership on completion/cancellation and exposes enough diagnostic information to explain which layer won.

The cell's `hitTest` is location-only and must never inspect `NSApp.currentEvent`; AppKit invokes hit testing during cursor/tracking updates where the current event may not be a mouse event. A concrete mouse event may only be inspected by the event-handling path that receives it explicitly.

## 6. Failure handling and edge cases

- A layer that does not claim a context must have no side effects.
- A claimed gesture must never also trigger the default row-selection or double-click callback.
- Double-click count and modifier flags must be captured from the concrete mouse event at sequence start, not inferred from global event state.
- Dragging across row boundaries must not transfer ownership.
- Missing/stale node IDs must safely fall back or cancel, never crash.
- Window deactivation, view teardown, or interrupted tracking must clear sequence ownership.
- Right/other mouse buttons must be classified explicitly and must not accidentally match primary-pointer-only layers.
- Native input focus and text selection take precedence over Tree interception.
- Existing drag/drop validation and host-owned move mutations remain unchanged.

## 7. Verification

### Automated
- Build the shared Swift package.
- Build and run the host app's existing macOS test suite.
- Add or extend host-side tests only where the arbitration logic can be tested without synthesizing fragile AppKit events; do not add a test target to the reusable component package solely to satisfy the architecture.
- Review source diffs for accidental behavior changes and verify the old initializer remains source-compatible.

### Manual interaction matrix
- Click a normal row: selection and row interaction occur once.
- Double-click a node title: editing starts once.
- Click disclosure: expansion/collapse works once.
- Click and drag within the filmstrip: the filmstrip owns the sequence; Tree selection and hierarchy drag do not start.
- Begin dragging in the filmstrip and cross its boundary: ownership remains with the filmstrip until release.
- Double-click in the filmstrip: it does not trigger node title editing.
- Drag a node from a non-embedded row: native Tree drag/drop remains functional.
- Click/type/select text in an active text field: native editing and text selection remain intact.
- Right-click/context menu and modifier-click selection remain consistent with current behavior.
- Switch windows or cancel an interaction mid-sequence: no stale owner remains.

## 8. Acceptance criteria

The work is complete when there is one documented arbitration path for pointer-down, one stable owner per pointer sequence, no duplicate lower-priority execution, the legacy API remains compatible, and the host app's existing build/tests pass. Manual AppKit behavior must be reported as manually verified only if actually exercised; automated build success is not evidence that pointer interactions work correctly.
