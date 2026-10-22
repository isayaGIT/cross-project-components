# Sticker Data Models

Shared, UI-independent data contracts for the cross-project sticker system.

## Models and ownership

- `Sticker`: one sticker, with a stable ID, owning `packID`, asset reference, optional display name, and search tags.
- `StickerAsset`: metadata and locations for an original image and optional thumbnail. Loading, decoding, caching, and byte storage belong to a repository/storage layer.
- `StickerPack`: one distributable collection of stickers. It owns pack metadata, a cover asset reference, version information, and an ordered list of sticker IDs.
- `StickerLibrary`: a discoverable catalog/index of available packs. It lists `packIDs`; it does not contain the sticker IDs inside each pack and does not represent a user's selection.
- `UserStickerConfiguration`: user-owned ordered pack selection, favorites, and recent stickers. It references IDs rather than duplicating catalog records.

The catalog publishes available packs; each pack organizes its stickers; user configuration determines which packs are added and in what order. The keyboard UI consumes these models and emits selected sticker IDs. It should not own catalog synchronization, persistence, or image caching.

The first fixed keyboard entries (search, default stickers, favorites) are UI concepts and are intentionally not stored as user-selected pack IDs.

## Identifier rules

IDs are opaque, stable strings supplied by the catalog or created by the importing layer. Do not use array positions, display names, or file paths as IDs. Reordering or updating a pack must not change its pack ID or the IDs of unchanged stickers.

## Example

```swift
let pack = StickerPack(
    id: "cute-animals",
    name: "Cute Animals",
    coverAssetID: "cute-animals-cover",
    version: "3",
    stickerIDs: ["cat-wave", "bunny-heart"]
)

let catalog = StickerLibrary(
    id: "community",
    name: "Community Sticker Library",
    packIDs: [pack.id]
)

var configuration = UserStickerConfiguration()
configuration.addPack(id: pack.id)
configuration.setFavorite(true, stickerID: "cat-wave")
configuration.recordUse(stickerID: "cat-wave")
```
