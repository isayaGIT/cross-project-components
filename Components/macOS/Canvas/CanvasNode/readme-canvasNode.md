`CanvasNodeView` accepts any SwiftUI `View` as its node content. The host application supplies the artwork (image, animated image, text, video, or a custom view); this package does not prescribe an asset format.

When selected, the node displays `CanvasNodeSelectionBorder`. Its configurable parameters are `color`, `lineLength`, `lineSpacing`, `weight`, `width`, and `height`.

Optional `CanvasNodeButtons` controls are anchored to the selection bounds: rotate at top-center, delete (`xmark`) at top-right, and resize at bottom-right. Delete runs on click; resize and rotate report incremental drag deltas. The host owns all model mutations and decides how those deltas affect its node.

The node's own transparent hit target remains responsible for selection and zoom-aware movement. Selection border and control overlays are layered above that target so they do not replace the existing movement gesture.