# Capsules

`CapsuleButton` is a borderless, accessible text action using a continuous `RoundedRectangle`, not SwiftUI's fixed `Capsule` shape.

```swift
CapsuleButton(
    "Good morning",
    background: .gray.opacity(0.12),
    foreground: .primary,
    cornerRadius: 16
) {
    // Handle selection
}
```

Background, foreground, corner radius, per-edge padding, font, and action are configurable. No border API is provided by design.
