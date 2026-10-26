# Card General

`CardGeneral` adds shape-aware thickness and elevation around caller-owned SwiftUI content. It does not draw the face, add inner padding, or arrange content.

```swift
CardGeneral(shape: RoundedRectangle(cornerRadius: 20, style: .continuous), palette: .pearl) {
    MyCardContent()
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
}

CardGeneral(shape: Circle(), palette: .graphite) {
    AvatarView()
}

MyCustomContent()
    .cardGeneral(shape: Capsule(), thickness: 5, palette: .sapphire)
```

## Shape and palette

Pass any SwiftUI `Shape`, including custom shapes. Use the same geometry for the caller-owned face and `CardGeneral` so the visible side and shadow align with the face. Built-in palettes: `.pearl`, `.graphite`, `.sapphire`, `.emerald`, `.amethyst`.

## Current implementation boundary

The API is shape-generic and the side silhouette/shadow use the supplied shape. The current side treatment is a native SwiftUI silhouette, not yet a pixel-matched port of Reflective Card's Metal shader. Shape-aware dynamic bevels and tilt-responsive edge highlights require the shader to consume a mask derived from the supplied shape; do not treat this implementation as the final reflective-material match.
