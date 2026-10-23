# MomentThumbnailService

A reusable Swift port of `cloud/services/moment_thumbs.py`. It handles backend thumbnail generation and caching for moment records; it does not implement feed rendering or any frontend UI.

## Source mapping

- `MomentThumbnailModels.swift`: moment and ready-result models, configuration values, gradient palettes, and typed errors.
- `MomentThumbnailService.swift`: cache paths, existing-thumbnail lookup, Twemoji retrieval/cache, deterministic palette selection, generation orchestration, and recent-moment maintenance.
- `ThumbnailPNGEncoder.swift`: dependency-free PNG chunk construction, CRC-32, Adler-32, and stored-DEFLATE stream encoding.
- `AppleMomentThumbnailProcessor.swift`: ImageIO/CoreGraphics JPEG cropping and gradient composition on supported Apple platforms, with a no-op fallback implementation elsewhere.

## Public API

Create `MomentThumbnailService` with a `MomentThumbnailConfiguration`. Call `generateThumbnail(for:force:)` to create or reuse one thumbnail. Call `ensureRecentThumbnails(for:limit:)` to process a bounded recent list and obtain `[{id, file}]`-equivalent `ReadyMomentThumbnail` values. A dictionary adapter is provided for backends that still receive the Python-style JSON dictionary shape.

The service is an actor, so its public asynchronous operations are serialized per instance. `MomentThumbnailHTTPClient` allows a custom HTTP transport. `MomentThumbnailImageProcessor` allows a deployment to provide its own image implementation or disable native processing by passing `imageProcessor: nil`.

## Configuration and cache layout

The caller supplies `momentsDirectory` and optionally `userImagesDirectory`. The service creates:

- `<momentsDirectory>/缩略图/` for thumbnail files.
- `<momentsDirectory>/缩略图/_emoji_cache/` for Twemoji PNG assets.

Existing thumbnails are checked in `.jpg`, `.jpeg`, `.png` order. A normal processed thumbnail is stored as `.jpg`; the no-image-processor fallback stores `.png` unless it copies a user image, in which case it uses the source extension. `force: true` skips reuse of the existing thumbnail. Cache invalidation is otherwise existence-based, matching the source implementation.

## Generation behavior

The service selects one of the source module's twelve color gradients using the MD5 digest of the UTF-8 moment identifier. Emoji code points are lowercase hexadecimal scalars joined by hyphens, excluding U+FE0F, and map to the version-pinned Twemoji CDN path. Network retrieval has a configurable timeout, a maximum accepted response size, and an injectable transport. Download failures are optional and fall back to a gradient.

When ImageIO/CoreGraphics are available, the default processor center-crops user photos into 256-by-256 JPEGs, or composes a gradient background and optional emoji into JPEG. The text fallback uses a portable CoreText font instead of the source's machine-specific font paths. Without native image processing, the service follows the Python fallback: copy a user image without cropping, use the Twemoji PNG directly when available, or emit a generated gradient PNG.

The PNG encoder creates valid RGB PNG chunks and checksums without a third-party compression library. It uses stored DEFLATE blocks rather than the Python implementation's zlib compression level; the pixel content and PNG validity are preserved, but encoded bytes are not expected to match Pillow or Python zlib byte-for-byte.

## Integration example

```swift
import Foundation

let service = MomentThumbnailService(
    configuration: MomentThumbnailConfiguration(
        momentsDirectory: savesDirectory.appendingPathComponent("moments", isDirectory: true),
        userImagesDirectory: userImagesDirectory
    )
)

let moment = MomentThumbnail(
    id: "moment-123",
    images: ["image_moment_user_abc.jpg"],
    text: "A day worth remembering"
)

let thumbnailURL = try await service.generateThumbnail(for: moment)
let ready = await service.ensureRecentThumbnails(for: [moment], limit: 12)
```

## Dependencies and limitations

The core service uses Foundation and URLSession. The Apple processor uses ImageIO, CoreGraphics, and CoreText only when those frameworks are available. There are no hardcoded application paths, credentials, third-party package requirements, or dependencies on the Python server runtime.

The caller remains responsible for providing moment records and selecting the storage directories. The non-Apple fallback intentionally does not resize or composite images; it copies source images or writes an emoji/gradient PNG, matching the original no-Pillow degradation strategy. The native processor uses platform JPEG encoding and a portable font, so visual output and JPEG bytes can differ slightly from Pillow's LANCZOS/quality-82/optimize output. Identifier sanitization follows Unicode alphanumeric and underscore/hyphen rules for ordinary identifiers; exotic Python `re` Unicode-word edge cases may differ. The service reports individual batch failures by omitting failed records, matching the original helper's failure-isolation behavior without printing directly to standard output.
