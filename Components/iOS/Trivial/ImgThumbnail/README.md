# ImgThumbnail

A lightweight SwiftUI thumbnail component for remote URLs and local `Image` values. Remote loading is handled by NukeUI's existing image pipeline; this component does not create its own cache or downloader.

## Usage

```swift
ImgThumbnail(
    url: photo.thumbnailURL,
    size: CGSize(width: 96, height: 72),
    shape: .roundedRectangle(cornerRadius: 10)
)

ImgThumbnail(
    image: Image("profile-photo"),
    size: CGSize(width: 48, height: 48),
    shape: .circle
)

ImgThumbnail(
    url: photo.url,
    size: CGSize(width: 120, height: 120),
    shape: .square
)
```

## Shapes and crop behavior

- `.rectangle`: unrounded rectangular thumbnail.
- `.roundedRectangle(cornerRadius:)`: continuous smoothed corners, using the shared `RoundedRectSmoothed` shape.
- `.square`: centered aspect-fill crop in a square whose side is the smaller requested dimension.
- `.circle`: the same centered square crop, clipped to a circle.

Images use aspect-fill and are clipped to the selected bounds, so they are not stretched. The URL initializer uses NukeUI's shared pipeline and its normal cache/downsampling behavior. A custom placeholder image can be passed to `placeholder`; `showsLoadingIndicator` controls the remote-loading indicator.
