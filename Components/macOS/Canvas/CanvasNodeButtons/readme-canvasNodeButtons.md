`CanvasNodeButton` exposes `icon`, `size`, `shape` (default: circle), optional `width` and `height`, plus optional `onClick` and `onDrag` callbacks. `onDrag` receives incremental `CGSize` deltas, not cumulative translation.

`CanvasNodeButtons` positions controls independently against the selection bounds: rotate at top-center, delete (`xmark`) at top-right, and resize at bottom-right. Supply `selectionWidth` and `selectionHeight` so the anchors match the selection box. Callbacks are optional; the host owns model mutations.
