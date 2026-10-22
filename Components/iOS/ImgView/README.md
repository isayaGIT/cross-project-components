# ImgView

A reusable SwiftUI full-screen image viewer for iOS 17+ with Nuke-backed loading, optional low-resolution preview URLs, swipe navigation, zoom gestures, and an injectable information panel.

## Features

- Low-resolution preview can appear while the original image is loading.
- Nuke/NukeUI handles asynchronous downloads, caching, request coalescing and image downsampling.
- Optional information panel is supplied by the host app; no AI provider, server endpoint, or chat model is hardcoded.
- Pinch-to-zoom, double-tap zoom, panning while zoomed, tap-to-close, and swipe navigation. A dedicated close control dismisses immediately, including while the image is loading.
- The info control has a clear selected state (white surface with dark icon). The separate `ImgViewInfoPanel` component supports downward-swipe dismissal without replacing gestures or controls inside its content.
- When multiple images are present, swipe horizontally to navigate. The viewer intentionally has no navigation arrows or image-count badge.
- Original-only URLs work too, with a loading and failure state.
- Zooming layers the original URL over the always-visible downsampled image. The high-resolution layer fades in when decoded, so the current zoom transform and layout are not reset during the upgrade.
- The top-right more menu saves the original file to Photos without re-encoding it. The host app must provide `NSPhotoLibraryAddUsageDescription` in its Info.plist.

## Use

```swift
import ImgView

@State private var isPresented = true
let photo = ImgViewImage(
    url: URL(string: "https://example.com/original.jpg")!,
    previewURL: URL(string: "https://example.com/thumbnail.jpg")!
)

ImgView(isPresented: $isPresented, images: [photo])
```

To add an app-owned AI information panel:

```swift
ImgView(
    isPresented: $isPresented,
    images: [photo],
    onInfoPanelPresented: { image in
        // Call your app's AI/image-understanding service here.
    }
) {
    VStack(alignment: .leading) {
        Text("AI image description")
        Button("Generate description") { /* trigger host-owned action */ }
    }
}
```

The information view is intentionally injected. The host application owns AI requests, persistence, descriptions, and loading/error states. The `onInfoPanelPresented` callback is optional and notifies the host when the information panel opens. The info panel is wrapped in the reusable `ImgViewInfoPanel` component; swiping it downward dismisses it and resets the info button to its inactive state. Its drag recognizer is simultaneous, preserving embedded controls.

## Large-image test fixture

`Tests/ImgViewPerformanceFixtures/large-landscape.jpg` is the repository-level 3648 × 5472 Unsplash fixture (downloaded at high quality) for manual memory and rendering checks. The sample app uses separate thumbnail and large-image URLs from the same photo. The test fixture's source and retrieval details are documented in `Tests/ImgViewPerformanceFixtures/README.md`.

## Build and test

```sh
swift test --package-path Components/iOS/ImgView
```

Open `Examples/ImgViewShowcaseApp` in Xcode as a Swift package app project or copy `ImgViewShowcaseApp.swift` into an iOS SwiftUI app target with the `ImgView` package dependency. The showcase uses a live image URL; the local fixture is for repeatable offline decode and memory testing.

## Run the showcase on an iPhone Simulator

From the repository root:

```sh
cd Components/iOS/ImgView/Examples/ImgViewShowcaseApp
xcodegen generate
open ImgViewShowcaseApp.xcodeproj
```

Choose an iPhone simulator and run `ImgViewShowcaseApp`. The first run needs network access to resolve Nuke and download the sample image. The AI panel is a UI demo only; its action is deliberately not connected to a real AI service.
