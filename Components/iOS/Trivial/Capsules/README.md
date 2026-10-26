# Capsules

`CapsuleButton` is a reusable, borderless SwiftUI action button. Its width follows its label, font, and padding; it does not impose a fixed width. The caller supplies the shape geometry, so rounded rectangles, `RoundedRectSmoothed`, and other SwiftUI shapes can be used without a `cornerRadius` property on the base component.

## Layer order

From back to front:

1. `texture` — drawn within and clipped to the supplied `shape`.
2. `border` — aligned to the same shape and drawn above the texture.
3. Text content.
4. `decor` — optional topmost overlay that may intentionally obscure text. Decor does not intercept button taps by default.

`HStack` is only a content layout container; it does not define the visual layer stack. The shape is a shared geometry input for texture clipping, border rendering, and hit testing.

## Basic usage

```swift
CapsuleButton(
    "Good morning",
    shape: AnyShape(RoundedRectangle(cornerRadius: 18, style: .continuous)),
    texture: .color(.gray.opacity(0.12)),
    border: .solid(color: .gray.opacity(0.25), lineWidth: 1),
    foreground: .primary
) {
    // Handle selection
}
```

## Korean-pink preset

```swift
CapsuleButtonPreset.hanPink("Recent search") {
    // Handle selection
}
```

The `hanPink` preset uses `RoundedRectSmoothed`, a muted gray-pink dashed border with a deliberately visible stroke, and a softly tinted surface. `Neumorphic Droplet` is deferred.

## Custom texture, border, and decor

```swift
CapsuleButton(
    "Decorated",
    shape: AnyShape(RoundedRectSmoothed(cornerRadius: 17)),
    texture: .custom(AnyView(MyLiquidGlassView())),
    border: .custom(AnyView(MyDashedBorderView())),
    decor: AnyView(MyAnimatedDecoration())
) {
    // Handle selection
}
```

For path-driven dashes, use `CapsuleButtonBorder.dashed(configuration:color:)`. The component derives the path from the supplied shape and lays it out at the button's measured size. Use `.custom(AnyView(...))` when an existing `DashedPath` setup needs custom phase, fill, or coordinate settings.
