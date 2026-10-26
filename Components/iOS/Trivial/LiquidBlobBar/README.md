# LiquidBlobBar

A generic SwiftUI horizontal layout that lets neighboring child views visually flow together. It accepts arbitrary caller-owned views and applies a static alpha-threshold fusion layer while keeping the original content sharp and interactive.

## Basic use

```swift
LiquidBlobBar {
    TextField("Message", text: $message)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.indigo, in: Capsule())

    Button(action: attach) {
        Image(systemName: "plus")
            .frame(width: 40, height: 40)
            .background(Color.indigo, in: Circle())
    }
    .buttonStyle(.plain)

    Button(action: send) {
        Image(systemName: "arrow.up")
            .frame(width: 40, height: 40)
            .background(Color.indigo, in: Circle())
    }
    .buttonStyle(.plain)
}
```

## Tuning

```swift
LiquidBlobBar(
    spacing: 3,
    fusionRadius: 9,
    fusionStrength: 0.9,
    fusionThreshold: 0.16,
    edgeSoftness: 0.12
) {
    firstView
    secondView
    thirdView
}
```

- `spacing` sets the same horizontal gap between every adjacent child.
- `fusionRadius` controls how far the decorative fusion layer spreads.
- `fusionStrength` controls the fusion layer opacity; set it to `0` to disable the effect.
- `fusionThreshold` controls how readily nearby surfaces merge; lower values create broader connections.
- `edgeSoftness` controls how softly the merged silhouette fades at its boundary.

## Ownership and appearance

LiquidBlobBar does **not** add a background, material, tint, border, or shape. Each child owns its own appearance, actions, accessibility labels, and layout. The non-interactive fusion layer is hidden from accessibility; the sharp foreground remains the only interactive row.

For the most visible fusion, children should already have visible surfaces (for example, their own capsules or circles). The decorative copy is blurred and its alpha is thresholded by a Metal shader, allowing nearby surfaces to form a single static silhouette. The caller-owned foreground is drawn normally on top. This does not depend on Liquid Glass or impose a background on the caller.

## Shader resources

The standalone Demo compiles `LiquidBlobBar.metal` directly into its app target. The Swift package includes precompiled iOS-device and iOS-simulator shader libraries so the shader is available from `Bundle.module`. If the Metal source changes, regenerate both libraries with:

```sh
./build-shaders.sh
```
