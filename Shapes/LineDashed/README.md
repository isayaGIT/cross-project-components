# LineDashed

A reusable SwiftUI dashed-path component. Each dash is an independent rounded rectangle positioned along a path by approximate arc length.

## Platforms

- iOS / iPadOS 17+
- macOS 13+ for the package API

## Usage

```swift
import LineDashed

LineDashed(
    path: path,
    configuration: .init(lineWidth: 3, dashLength: 10, dashSpacing: 5, cornerRadius: 2),
    fill: .color(.blue)
)
```

Conveniences are available for `rect:` and `roundedRect:cornerRadius:`. `fillCoordinates` can be `.pathContinuous` (default) or `.perSegment`. Set `phase` to shift the dash pattern; animate it only when marching-dash behavior is wanted.

## Configuration behavior

- Defaults: width 2 pt, dash length 8 pt, spacing 4 pt, corner radius 1 pt.
- Non-finite/non-positive width and dash length normalize to zero and render nothing.
- Negative or non-finite spacing and radius normalize to zero.
- Corner radius is clamped to half the smaller segment dimension.
- Empty/degenerate paths render nothing.
- Closed paths default to even distribution; `.fixedLengthAndSpacing` preserves configured dimensions.

## Build and test

```sh
swift test --package-path Shapes/LineDashed
swift build --package-path Shapes/LineDashed
```

The interactive iOS Showcase is in `Examples/LineDashedShowcaseApp`; regenerate its Xcode project with `xcodegen generate` from that directory.

## Current limitations

The path engine flattens quadratic and cubic curves with an internal tolerance, so curved-path placement is approximate. Checkerboard and grid fills are supported by the drawing renderer. The material types currently define the platform-adapter API surface only; system Material and Liquid Glass are not yet wired into the public `LineDashed` view. The first version also does not yet expose a dedicated animation configuration type; callers can animate the `phase` parameter themselves.
