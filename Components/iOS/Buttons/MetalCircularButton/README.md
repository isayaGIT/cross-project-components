# MetalCircularButton

A reusable SwiftUI circular button whose face is extracted directly from `DesignIdeas/buttons/截屏2026-10-27 上午2.22.30.png`. The original brushed-metal machining pattern, radial highlight convergence, silver tonal variation, and rim pixels are preserved from the reference. A supersampled circular alpha mask removes the screenshot canvas and the horizontal rail; a small external shadow restores the button's lift without repainting its face.

## Usage

```swift
MetalCircularButton(diameter: 82.33, accessibilityLabel: "Open") {
    openDestination()
}
```

The default 82.33-point diameter maps the 247-pixel source face to approximately 247 physical pixels on a 3× display. Pass another diameter to scale it. The face image is bundled in the iOS package resources. The face itself is a reference texture rather than a procedural shader: for a static, pixel-faithful match, retaining the source pixels is more accurate and simpler than synthesizing a similar-looking material at runtime.
