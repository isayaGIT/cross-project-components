# Generated Chat Bubble Pack

First local prototype of animated chat-bubble assets inspired by the images in the parent `chatbubble` folder. Existing reference images are not modified.

## Contents
- `bubbles/`: 6 looping transparent animated WebP bubble concepts.
- `stickers/`: 4 independent transparent animated WebP sticker assets plus PNG posters.
- `previews/`: GIF previews, poster PNGs, and a contact sheet.
- `manifest.json`: asset index.

## Notes
- These are original procedural prototype assets, not pixel-traced copies of the references.
- GIF is provided for convenient preview; GIF transparency is limited to binary transparency, so use WebP for cleaner edges where the consuming platform supports animated WebP.
- The bubble interiors use abstract placeholder lines, not real text. In production, render text as native SwiftUI text above the bubble.
- Verify target-platform Animated WebP decoding and memory/performance before integrating into the app.
