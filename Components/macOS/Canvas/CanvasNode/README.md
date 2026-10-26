# CanvasNode

`CanvasNodeView` is a reusable SwiftUI wrapper for an individual canvas node. It owns the transparent hit target, click-to-select behavior, selected outline, and zoom-aware drag translation. The host application supplies the node artwork and applies position updates to its own document model.

```swift
CanvasNodeView(
    id: layer.id,
    position: CGPoint(x: layer.x, y: layer.y),
    hitSize: CGSize(width: layer.size + 38, height: layer.size + 38),
    zoom: zoom / 100,
    isSelected: selectedID == layer.id,
    onSelect: { selectedID = $0 },
    onPositionChange: { point in
        project.updateLayer(id: layer.id) {
            $0.x = point.x
            $0.y = point.y
        }
    }
) {
    LayerArtwork(layer: layer, isPlaying: isPlaying, previewTime: previewTime)
}
```

The component does not depend on a host-specific model type and can be used by other canvas-based applications.
