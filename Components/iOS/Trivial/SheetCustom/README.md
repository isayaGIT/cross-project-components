# SheetCustom

A reusable SwiftUI bottom-sheet overlay for iOS 17+. It does not use the system sheet presentation API.

```swift
@State private var isPresented = false

ZStack {
    Button("Open") { isPresented = true }
    SheetCustom(
        isPresented: $isPresented,
        configuration: .init(height: .fraction(0.6), cornerRadius: 24)
    ) {
        Text("Custom sheet content")
            .padding(24)
    }
}
```

`SheetCustomConfiguration` controls fixed-point or available-height-fraction sizing, panel and backdrop colors, top corner radius, grabber visibility, and backdrop/drag dismissal. The presenter owns visibility and supplies content. Compose it in an overlay or root `ZStack` so it can cover the intended screen region.
