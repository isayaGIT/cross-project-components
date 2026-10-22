# MessageBubble

A native SwiftUI primitive for chat bubbles. One public view supports two silhouettes and optional timestamp metadata while keeping message models, sender grouping, and time formatting in the host app.

## Responsibilities

- `MessageBubbleShape` owns the bubble outline and can be used directly with standard SwiftUI shape APIs.
- `MessageBubbleStyle.tailLess` preserves the original single-shape silhouette with a configurable square corner.
- `MessageBubbleStyle.roundedTail` draws a rounded bubble with an integrated lower-leading or lower-trailing tail in the same path. It does not layer a separate triangle over a rounded rectangle.
- `MessageBubble<Content>` owns fill, content insets, optional dimensions, an optional outline, and optional timestamp presentation outside the bubble.
- `MessageBubbleBorder` supports no border, a solid SwiftUI stroke, or the reusable `LineDashed` renderer with configurable dash geometry, fill, fill-coordinate mode, and phase. The outline uses the same final bubble path as the fill, so it follows the selected corner/tail geometry and the content’s measured size.
- The host app owns message data, sender alignment in the conversation, grouping rules, timestamp formatting/localization, delivery state, and interactions.

No chat timeline, networking, message model, theme engine, effect registry, or third-party dependency is included.

## Requirements

Swift 5.9+, iOS 17+ (the package's existing deployment target).

## Usage

```swift
import SwiftUI

MessageBubble(
    sharpCorner: .bottomLeading,
    style: .roundedTail,
    fill: Color.gray.opacity(0.16),
    timestamp: "16:08",
    metadataAlignment: .leading,
    font: .system(size: 17, weight: .medium),
    lineSpacing: 4
) {
    Text("An incoming message")
        .foregroundStyle(.primary)
}

MessageBubble(
    sharpCorner: .bottomLeading,
    style: .roundedTail,
    fill: Color.gray.opacity(0.12),
    border: .dashed(
        configuration: .init(lineWidth: 2, dashLength: 7, dashSpacing: 4, cornerRadius: 1),
        fill: .color(.purple)
    )
) {
    Text("A message with a configurable dashed outline")
}

MessageBubble(
    sharpCorner: .bottomTrailing,
    style: .tailLess,
    fill: LinearGradient(
        colors: [.blue, .cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    ),
    timestamp: "16:09",
    metadataAlignment: .trailing
) {
    Text("An outgoing message")
        .foregroundStyle(.white)
}
```

The `font` parameter controls the message content's inherited SwiftUI font (default `.body`), and `lineSpacing` controls additional spacing between lines (default `0`). Both apply to text inside the content closure unless an individual child explicitly overrides the font or line spacing. You can also set `.font(...)` and `.lineSpacing(...)` directly on individual views when mixed typography is needed. The timestamp is optional. `nil` and an empty string both omit it without reserving space. Supply an already formatted string so the component stays independent of locale, time zone, and the app's message model. Set `metadataAlignment` to `.leading` for incoming messages and `.trailing` for outgoing messages.

For shape-only use:

```swift
MessageBubbleShape(
    cornerRadius: 18,
    sharpCorner: .bottomTrailing,
    style: .roundedTail
)
.fill(.blue)
.frame(width: 220, height: 84)
```

## API decisions

- One `MessageBubble` API; silhouette is selected through `MessageBubbleStyle` rather than parallel bubble types.
- The tail is part of a single path, so fill and stroke follow one continuous outline.
- Only lower-leading and lower-trailing corners produce a tail. If another corner is selected with `.roundedTail`, the shape safely falls back to the tail-less geometry.
- Timestamp is rendered outside the shape and only when non-empty. It is presentation metadata, not part of the content closure or shape geometry.
- Fonts, colors, effects, accessibility for message content, and sender layout remain customizable through SwiftUI and the host app.
