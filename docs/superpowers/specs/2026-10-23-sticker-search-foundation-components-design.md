# Sticker Search and Foundation Components Design

## Goals
- Tighten StickerKeyboard sticker spacing with one equal horizontal/vertical spacing value and square image clipping.
- Keep `BottomSheet` as the reusable, non-system sheet container, with configurable height, background, and optional top border-line view.
- Add reusable `Background` and `ColorCustom` abstractions for image, material, solid, and gradient backgrounds.
- Add `TextFieldCustom` with configurable shape, background, placeholder, font, and optional border line.
- Keep `CapsuleButton` width content-driven and use it for a one-row horizontally scrolling recent-search list.
- Simplify `StickerSearchSheet` to recent searches plus an input field, defaulting to 75% available screen height.

## Architecture
- `BottomSheet` owns presentation, sizing, backdrop, drag dismissal, and top-edge decoration. It accepts arbitrary SwiftUI content and does not depend on search behavior.
- `Background` is a reusable view-style abstraction; `ColorCustom` models solid and gradient fills.
- `TextFieldCustom` owns text input styling and input callbacks only. Search history remains in `StickerSearchSheet`.
- `CapsuleButton` measures naturally from its text/font/padding and does not impose a fixed width.
- `StickerSearchSheet` embeds its own input view in `BottomSheet`, uses a single horizontal scroll row, stores at most ten recent submitted searches, and removes duplicate entries before inserting a new most-recent value.

## Compatibility
- Use the vendored upstream BottomSheet API directly without a custom adapter.
- Keep the existing `CapsuleButton` initializer source-compatible; improve sizing internally.
- Preserve `StickerSearchSheet(isPresented:configuration:onSearch:)` and existing configuration colors where practical.

## Validation
- Build the component package and standalone StickerKeyboard demo for iOS Simulator.
- Install and launch the demo, capture a screenshot, and inspect logs for launch/build failures.
- Verify source-level API compatibility at existing call sites and that the demo uses the vendored BottomSheet package rather than system `.sheet` for sticker search.
