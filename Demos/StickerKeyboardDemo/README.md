# StickerKeyboardDemo

An isolated iOS playground for the repository's real `StickerKeyboard.swift` implementation.

## Open

Open `StickerKeyboardDemo.xcodeproj` in Xcode and run the `StickerKeyboardDemo` scheme on an iOS Simulator (iOS 17+).

The app links the actual `StickerKeyboard.swift` file and the `Class/Sticker` model sources. It does not depend on the previous host app or on `StickerSearchSheet`; the search button opens a small host-side callback test sheet so keyboard behavior can be checked independently.

## What to test

- Emoji selection updates the draft and selection status.
- Favorites and the two demo sticker packs can be switched from the category bar.
- Sticker taps update the draft and selection status.
- Search opens the host test sheet and reports the submitted query.
- Remote thumbnail and pack-cover image loading can be checked visually. Network images require an internet connection.
