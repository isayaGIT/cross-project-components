# Glow in Dark Button

A native SwiftUI recreation of [Button Effect (Glow in Dark) by uixamjad](https://dribbble.com/shots/24861922-Button-Effect-Glow-in-Dark).

## Use

```swift
GlowInDarkButton("Get Started", width: 240, height: 78) {
    // Handle the action.
}
```

`GlowInDarkButton` draws only the control. It does not impose a background, so it can be composed on a caller-owned dark surface. `GlowInDarkButtonShowcase` is an optional preview surface that adds the faint grid from the reference.

## Fidelity notes

The provided source in this folder is a static WebP image. The dark pill, right-biased silver rim, luminous label, low-contrast bloom, tiny specular points, and faint grid are recreated with SwiftUI drawing layers. The subtle looping glow and press feedback are implementation interpretations; the original motion timing could not be confirmed from the supplied static asset.
