# SheetCustom

A reusable SwiftUI bottom-sheet overlay for iOS 17+. It does not use the system sheet presentation API.

```swift
@State private var isPresented = false

SheetCustom(
    isPresented: $isPresented,
    configuration: .init(
        height: .fraction(0.75),
        customBackground: Background(material: .ultraThinMaterial),
        borderLine: AnyView(Rectangle().fill(.secondary).frame(height: 1))
    )
) {
    Text("Any SwiftUI content")
}
```

`SheetCustomConfiguration` controls fixed-point or available-height-fraction sizing, backdrop, corner radius, grabber, dismissal behavior, a `Background` style, an optional top-edge border-line view, and an optional outer border (`border` and `borderWidth`). Existing `background: Color` call sites remain supported. When enabled, dragging starts from the grabber only and dismissal requires dragging the panel until approximately one-third of the screen height remains. The presenter owns visibility and supplies arbitrary content.
