# StickerKeyboard

A lightweight, reusable SwiftUI image-sticker keyboard for iOS 17+. The panel renders image assets using `NukeUI`'s lazy image loader, so thumbnails load on demand and use Nuke's request/cache pipeline. The host supplies data and remains responsible for persistence, focus, draft insertion, and panel placement.

## Image sticker keyboard

```swift
import StickerData

StickerKeyboard(
    stickers: stickers,
    packs: packs,
    assets: assets,
    userConfiguration: userStickerConfiguration,
    defaultPackID: "default",
    onSearch: { query in /* search the app-wide sticker catalogue */ },
    onSearchRequested: { /* present StickerSearchSheet at the app/root overlay */ },
    onSelect: { sticker in
        // Resolve the selected sticker/asset and insert it into the message.
    }
)
```

`StickerKeyboard` accepts the app's sticker models; it does not fetch catalog metadata or persist favorites/recent usage. `UserStickerConfiguration.selectedPackIDs` controls the visible pack order. The first three category entries are search, the configured default pack, and favorites. Additional tabs are the selected packs in their configured order. The first category opens `StickerSearchSheet`, which is deliberately separate from installed-pack browsing. Its `onSearch` callback is a handoff point for the app-wide sticker catalogue; this component does not pretend to connect a backend. The search sheet is presented by `SheetCustom`, defaults to 85% of available screen height. It lists the provided sticker packs (title, short description, tags) in randomized order. Tapping a pack opens its detail view with all pack stickers plus install, delete, and like actions. The app owns those actions and passes installed/liked state and callbacks. Recent-search capsules sit immediately above the compact search field, with the search action on the right.

`StickerAsset.thumbnailLocation` is preferred for the grid; `originalLocation` is the fallback. Supply appropriately sized thumbnails for best scrolling performance. `LazyVGrid` creates cells on demand and Nuke manages image loading/caching. Remote URLs and local file URLs supported by Nuke can be used.

## Layout contract

`StickerKeyboard.defaultHeight` and `Configuration.height` expose the panel's preferred height. The component does not offset or resize the host input bar; the host owns layout and keyboard transitions.

```swift
let configuration = StickerKeyboard.Configuration(height: 300, columns: 5)
```

The standard height is 286 points. Columns are clamped to `3...10`, sticker size to `36...100` points, and category bar height to at least 40 points.

A compatibility initializer for the earlier Unicode picker remains available for existing callers. New integrations should use the data-driven initializer above.

## Related reusable UI

- `../SheetCustom`: configurable custom overlay sheet with point/fraction sizing and theme colors.
- `../Capsules`: borderless text action capsule using a continuous rounded rectangle.
