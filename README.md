# Cross-Project Components

Reusable native macOS UI components packaged as a Swift Package.

## TreeView

A SwiftUI-facing, AppKit-backed hierarchical tree. The host keeps ownership of its model, persistence, and domain rules; the component handles the native outline interaction.

![TreeView demo](Examples/tree-view.gif)

Features include controlled selection and expansion, ancestor-preserving search, custom SwiftUI rows, per-node row heights, disclosure alignment, native drag-and-drop with host validation, and pointer-event routing for interactive row content.

API contract: [Documentation/Tree-API.md](Documentation/Tree-API.md).

## FilmstripScrubber

A continuous, pixel-based image-strip scrubber for browsing image sequences.

![FilmstripScrubber demo](Examples/filmstrip-scrubber.gif)

## Add to a project

In Xcode, choose **File → Add Package Dependencies…** and enter:

```text
https://github.com/isayaGIT/cross-project-components
```

Select the `CrossProjectComponents` product.

For a Swift Package, add the dependency using the release version you want:

```swift
.package(url: "https://github.com/isayaGIT/cross-project-components", from: "1.1.0")
```

## TreeView integration

Conform a host model to `TreeNodeRepresentable`, then provide bindings for selection and expansion:

```swift
import CrossProjectComponents
import SwiftUI

struct OutlineNode: TreeNodeRepresentable {
    let id: UUID
    let title: String
    let children: [OutlineNode]

    var treeID: UUID { id }
    var treeTitle: String { title }
    var treeChildren: [OutlineNode] { children }
}

struct OutlineSidebar: View {
    let root: OutlineNode
    @State private var selectedID: UUID?
    @State private var expandedIDs: Set<UUID> = []

    var body: some View {
        TreeView(
            root: root,
            selection: $selectedID,
            expandedIDs: $expandedIDs,
            canMove: { sourceID, targetID, placement in
                // Validate domain rules without mutating the model.
                sourceID != targetID
            },
            onMove: { sourceID, targetID, placement in
                // Apply the accepted move to your model and publish the new root.
            }
        ) { context in
            Text(context.node.title)
                .lineLimit(1)
        }
    }
}
```

The example shows the integration boundary, not a complete move implementation: the host must reject invalid hierarchy changes (including cycles), mutate its own model in `onMove`, and update `root`. See the API contract for details.

## Requirements

- macOS 13 or later
- Swift tools 5.9 or later
- SwiftUI and AppKit
