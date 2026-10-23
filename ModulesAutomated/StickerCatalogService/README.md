# StickerCatalogService

Reusable native Swift port of `cloud/services/stickers.py`. This is a backend-only service: it does not render stickers, serve HTTP routes, or depend on browser/UI code.

## Source mapping

- `_safe_sticker_path` → `StickerCatalogPath.safeRelativePath(_:)`
- `load_catalog` → `StickerCatalogService.loadCatalog()`
- `sticker_prompt_block` → `StickerCatalogService.promptBlock(catalog:maxItems:)`
- `normalize_sticker_id` → `StickerCatalogService.normalizeStickerID(_:catalog:)`

The source module imports only Python's `json` and `pathlib`; the Swift implementation uses Foundation JSON parsing and URL-based filesystem configuration.

## Architecture

- `StickerCatalogModels.swift` defines the normalized entry, configuration, typed errors, and injectable filesystem protocol.
- `StickerCatalogPath.swift` isolates source-compatible path normalization and offers an additional standardized-URL containment helper for filesystem consumers.
- `StickerCatalogService.swift` loads and normalizes the catalog, sorts entries, formats prompt context, and resolves IDs.

`StickerCatalogService` is an actor. It serializes operations for a service instance but does not cache the catalog, so changes to `descriptions.json` are visible on the next operation. The local filesystem adapter is the default; applications can supply another `StickerCatalogFileAccess` implementation.

## Public API

- `StickerCatalogConfiguration(stickersRoot:assetURLPrefix:)`
- `StickerCatalogConfiguration.fromAssetsRoot(_:assetURLPrefix:)`
- `StickerCatalogService(configuration:fileAccess:)`
- `await service.loadCatalog()`
- `await service.promptBlock(maxItems:)`
- `await service.normalizeStickerID(_:)`
- `StickerCatalogService.promptBlock(catalog:maxItems:)`
- `StickerCatalogService.normalizeStickerID(_:catalog:)`
- `StickerCatalogPath.safeRelativePath(_:)`
- `StickerCatalogPath.isContained(relativePath:under:)`

Catalog entries expose `id`, `path`, `file`, `collection`, `description`, and `url` as Codable, Equatable, Hashable, Sendable fields.

## Usage

```swift
import Foundation

let stickersDirectory = URL(fileURLWithPath: "/srv/app/assets/Stickers", isDirectory: true)
let service = StickerCatalogService(stickersRoot: stickersDirectory)

let catalog = await service.loadCatalog()
let promptContext = StickerCatalogService.promptBlock(catalog: catalog, maxItems: 40)
let resolvedID = StickerCatalogService.normalizeStickerID("happy.png", catalog: catalog)
```

In production, inject the configured assets directory rather than embedding a machine-specific path in reusable library code.

## Compatibility behavior

- A missing, unreadable, or malformed catalog returns an empty array, matching the Python loader's defensive fallback.
- A non-object root or non-object entry is ignored.
- The accepted path normalization replaces backslashes, trims surrounding whitespace, strips leading slashes, and rejects empty paths or any path component exactly equal to `..`.
- The output URL is the configured prefix plus the normalized path; the default prefix matches `/assets/Stickers/`.
- Empty or false-like metadata values fall back to the basename for `file`, and empty strings for `collection` and `description`.
- Entries are sorted by collection, then file. Prompt output uses a full-width Chinese colon and newline separators.
- Identifier resolution checks exact ID matches first. It then scans catalog order for the first path-suffix or exact filename match.
- Prompt limits are nonnegative by default at 40; negative values emulate Python's `catalog[:max_items]` slicing semantics.

## Path-safety notes and limitations

The source rule blocks `..` components but does not reject every possible absolute-path form after its leading-slash normalization, nor does it resolve filesystem symlinks. `safeRelativePath` deliberately preserves that identifier behavior for compatibility. When a catalog identifier is used to access a real file, call `isContained(relativePath:under:)` and apply any platform-specific symlink policy required by the host application. This service resolves metadata only; it does not assert that each referenced sticker asset exists.

Python's `str()` coercion for unusual non-string metadata values does not have a perfectly identical Foundation representation. Typical catalog string values and all documented fallback paths are supported. The filesystem dependency is synchronous and lightweight; callers may run it on an appropriate executor if their environment requires nonblocking disk access.
