# Screen Miniature

A small SwiftUI component experiment that displays supplied view content at a reduced size and disables hit testing inside the miniature.

## Component

```swift
ScreenMiniature(
    sourceSize: CGSize(width: 390, height: 844),
    size: CGSize(width: 117, height: 253.2)
) {
    ExistingScreen(sharedModel: model)
}
```

Pass the same observable state/model to the source screen and miniature if changes should appear in both. The component scales the provided SwiftUI content to fit the target size and clips overflow.

## Important limitation

This is not a screenshot of an already-running screen and does not duplicate an existing `UIWindow`. SwiftUI renders the supplied content in a second view hierarchy. To avoid duplicate business effects, share state and keep network requests, timers, and other side effects outside the view body or in a single shared owner. Capturing the actual currently rendered screen would require a separate snapshot/screen-capture approach.

## Demo

Open `Examples/ScreenMiniatureDemo/ScreenMiniatureDemo.xcodeproj` or regenerate it with XcodeGen from `Examples/ScreenMiniatureDemo/project.yml`. The demo presents an interactive source screen and a non-interactive miniature sharing the same model. Tap Send on the source to verify both update.
