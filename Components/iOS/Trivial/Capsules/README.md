# Capsules

`CapsuleButton` is a borderless, accessible text action using a continuous rounded rectangle. Its width follows its text, font, and horizontal padding; it does not impose a fixed width.

```swift
CapsuleButton(
    "Good morning",
    background: .gray.opacity(0.12),
    foreground: .primary,
    cornerRadius: 18
) {
    // Handle selection
}
```

Background, foreground, corner radius, per-edge padding, font, and action are configurable. No border API is provided by design.
