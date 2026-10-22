# ImgPolaroid

A lightweight SwiftUI component for rendering and interacting with **one Polaroid card**. The host app owns image loading, placement persistence, and composition; this package provides the card and its direct-manipulation gestures.

## Interaction

- Tap to toggle the raised/selected state.
- Press and hold briefly to raise/select the card without moving it.
- Drag the card to move it with immediate pointer tracking and a stable release.
- Drag directly from either top corner to rotate the card. No rotation buttons or handles are shown.
- Rotation follows the finger’s angular movement around the card center; both corners use the same geometry with mirrored direction handling rather than a fixed pixels-to-degrees multiplier.
- Optional callbacks report drag state and interactive rotation.

## Usage

```swift
import SwiftUI
import ImgPolaroid

struct PhotoExample: View {
    @State private var offset = CGSize.zero
    @State private var selected = false
    @State private var rotation = -4.0

    var body: some View {
        Polaroid(
            image: Image(uiImage: photo),
            caption: "Summer, 2026",
            width: 180,
            rotation: $rotation,
            position: $offset,
            isRaised: $selected,
            onRotationChange: { rotation = $0 }
        )
    }
}
```

`position` is an offset from the card's layout anchor. Pass a `rotation` binding if the host app should own and persist the angle; without one, the component keeps the interactive angle internally. `onRotationChange` can notify the host app. The package does not download images or write state to disk.

## Build

```sh
swift build --package-path Components/iOS/ImgPolaroid --scratch-path /tmp/img-polaroid-build
```

The showcase Xcode project is generated from `Examples/ImgPolaroidShowcaseApp/project.yml` using XcodeGen (`xcodegen generate`).
