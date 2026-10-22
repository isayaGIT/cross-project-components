# Avatar

A lightweight SwiftUI component for displaying an avatar with consistent sizing, scaling, and clipping.

## Responsibility boundary

`Avatar` is presentation-only. It does not download images, own a cache, persist avatar files, or manage network retries. The caller or a separate image-loading module resolves the image and passes the resulting SwiftUI `Image` to this component.

```swift
import Avatar

Avatar(
    image: Image(uiImage: profileUIImage),
    width: 48,
    height: 48,
    shape: .circle
)
```

Show a neutral placeholder while the image is unavailable:

```swift
Avatar(
    image: nil,
    width: 48,
    height: 48,
    shape: .circle
)
```

When `image` and `placeholder` are both `nil`, Avatar draws a vector person silhouette by default. Customize its background and silhouette colors with `placeholderStyle: .init(background: ..., foreground: ...)`. An optional `placeholder` image can be supplied when a specific placeholder is desired. The component also supports `.roundedRectangle(cornerRadius:)` and `.square` shapes, plus `.fill` and `.fit` scaling.

Double-tap wobble can be enabled with `pokeEnabled: true`. The `vibration` parameter controls the accompanying iOS haptic intensity from `0` to `1`: `0` disables vibration (the default), and `1` uses full/default impact intensity. Values are clamped to this range. For example:

```swift
Avatar(
    image: Image(uiImage: profileUIImage),
    width: 48,
    height: 48,
    pokeEnabled: true,
    vibration: 1
)
```

## Build

Run `./build.sh` from this directory. Build outputs and logs stay under this component's ignored `.build/` directory.
