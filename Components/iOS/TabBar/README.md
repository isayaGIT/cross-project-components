# TabBar

A reusable SwiftUI tab bar with an animated selection capsule and a bottom black fade. Supports 1–6 tabs.

```swift
@State private var selectedTab = "home"

TabBar(
    items: [
        .init(id: "home", title: "Home", systemImage: "house"),
        .init(id: "search", title: "Search", systemImage: "magnifyingglass"),
        .init(id: "profile", title: "Profile", systemImage: "person")
    ],
    selection: $selectedTab
)
```

The default texture is `.material`. Opt into the bundled LiquidGlassKit implementation with `texture: .liquidGlass`. The texture choice is independent of tab selection and layout. If LiquidGlassKit is unavailable on the current build platform, the Liquid Glass option falls back to system material.

`onSelect` is optional; selection is already updated through the binding. The caller owns navigation and destination content.
