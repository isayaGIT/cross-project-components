# StickerKeyboard

A lightweight SwiftUI Unicode emoji picker for iOS 17+.

```swift
StickerKeyboard { emoji in
    draft.append(emoji)
}
```

`StickerKeyboard` reports the selected emoji through `onSelect`; it does not own or edit a message draft, manage text-field focus, or position itself relative to an input bar.

Use `StickerKeyboard.Configuration` to configure the panel's preferred height and emoji grid column count. `StickerKeyboard.defaultHeight` exposes the standard panel height for hosts that need a layout contract. The height is measured in points; values below 180 points are clamped, and columns are clamped to 4...12.

```swift
let pickerConfiguration = StickerKeyboard.Configuration(height: 300, columns: 8)
StickerKeyboard(configuration: pickerConfiguration) { emoji in
    draft.append(emoji)
}
```

The component uses native Unicode emoji glyphs and SF Symbols, with no image assets or third-party runtime dependency.
