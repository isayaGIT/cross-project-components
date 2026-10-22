# Image Resource Models

UI-independent, cross-project data contracts for image resources and their server-generated variants.

## Models

- `Img`: a logical image with a stable ID, optional alternative text, and the variants currently available.
- `ImgVariant`: a fetchable representation such as a thumbnail, preview, high-resolution derivative, or original file. It records the URL and optional dimensions, encoded byte size, and media type.

## Responsibilities

These models describe image assets; they do not upload files, transcode images, download bytes, decode pixels, or cache responses.

- The upload/media service preserves the original and generates variants.
- The API returns the `Img` and its available `ImgVariant` metadata.
- A UI component such as `ImgView` chooses an appropriate variant and presents loading/error states.
- The image pipeline (currently Nuke on iOS) handles downloading, decoding, and client-side caching.

## Example

```swift
import ImgData

let image = Img(
    id: "photo-123",
    variants: [
        ImgVariant(kind: .thumbnail, url: URL(string: "https://cdn.example.com/photo-123-240.webp")!, pixelWidth: 240, pixelHeight: 180, mediaType: .webp),
        ImgVariant(kind: .preview, url: URL(string: "https://cdn.example.com/photo-123-1280.webp")!, pixelWidth: 1280, pixelHeight: 960, mediaType: .webp),
        ImgVariant(kind: .original, url: URL(string: "https://media.example.com/photo-123")!, pixelWidth: 8000, pixelHeight: 6000, byteCount: 25_000_000, mediaType: .jpeg)
    ],
    altText: "Mountain landscape"
)

let initialImageURL = image.bestPreviewVariant?.url
let originalURL = image.originalVariant?.url
```

Variant URLs are examples only. Do not assume every service offers every variant; check availability and fall back when needed.
