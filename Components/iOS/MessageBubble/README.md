# MessageBubble

A native SwiftUI primitive for chat bubbles. One public view supports two silhouettes and optional timestamp metadata while keeping message models, sender grouping, and time formatting in the host app.

## Responsibilities

- `MessageBubbleShape` owns the bubble outline and can be used directly with standard SwiftUI shape APIs.
- `MessageBubbleStyle.tailLess` preserves the original single-shape silhouette with a configurable square corner.
- `MessageBubbleStyle.roundedTail` draws a rounded bubble with an integrated lower-leading or lower-trailing tail in the same path. It does not layer a separate triangle over a rounded rectangle.
- `MessageBubble<Content>` owns fill, content insets, optional dimensions, an optional outline, optional timestamp presentation, and an optional theme render layer.
- `MessageBubbleTheme` holds reusable Lottie decorations independently from message content. Each decoration configures its bundled animation name, placement (clipped inside the silhouette or overlapping its edge), size, alignment, offset, and loop mode.
- `NinePatchFrameAnimation` plays PNG frame sequences using native UIKit image cap insets, so each frame is nine-sliced before display; it supports duration, finite/infinite repeat, and horizontal mirroring. `BubbleNineSliceGrid` models the nine fixed/stretchable regions for geometry tests and tooling. `BubbleNineSliceAdjustment` safely decodes the six-operation legacy hex convention into typed operations, and `BubbleNineSliceOperation` implements the six documented arithmetic rules.
- `MessageBubbleBorder` supports no border, a solid SwiftUI stroke, or the reusable `LineDashed` renderer with configurable dash geometry, fill, fill-coordinate mode, and phase. The outline uses the same final bubble path as the fill, so it follows the selected corner/tail geometry and the content’s measured size.
- The host app owns message data, sender alignment in the conversation, grouping rules, timestamp formatting/localization, delivery state, and interactions.

No chat timeline, networking, or message model is included. Lottie is used only by the optional animated-decoration renderer; `NinePatchFrameAnimation` is the primary option for animated bubble skins made from PNG frames. A bubble without decorations renders as before.

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
    configuration: .init(
        style: .roundedTail,
        sharpCorner: .bottomTrailing,
        fill: AnyShapeStyle(Color.pink.opacity(0.18)),
        theme: MessageBubbleTheme(decorations: [
            .init(
                animationName: "SparkleBow",
                placement: .overlapping,
                size: CGSize(width: 56, height: 56),
                alignment: .topTrailing,
                offset: CGSize(width: 12, height: -10)
            )
        ])
    )
) {
    Text("A message with an animated theme decoration")
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


### PNG nine-patch frame animation

```swift
NinePatchFrameAnimation(
    frameNames: (1...12).map { "bubble_frame_\($0)" },
    sourceSize: CGSize(width: 128, height: 112),
    stretchInsets: EdgeInsets(top: 37, leading: 31, bottom: 37, trailing: 38),
    duration: 1.2,
    repeatCount: 3,
    horizontallyMirrored: false
)
.frame(height: 92)
```

The frame names must resolve through `UIImage(named:)` (for example, images in the host app's asset catalog). Insets are measured in points in the source image coordinate system. The frame sequence is nine-sliced independently, preserving the corners while allowing the stretchable center to adapt to the view's dimensions. `repeatCount: 0` means repeat indefinitely.

### Nine-slice animation adaptation

Use `BubbleNineSliceGrid` to keep corner insets stable while the horizontal and vertical center bands absorb the bubble's size delta. `BubbleNineSliceAdjustment` is a typed codec for the six hexadecimal operation digits (`sssppp`); do not perform layout arithmetic on the packed integer. The six operations are difference add/subtract, ratio multiply, half-difference add/subtract, and source-dimension-based image-scale adjustment. The codec expects each hex digit to be an operation code from `0` through `5`. The grid is geometry infrastructure; each Lottie theme still supplies an animation asset designed to use the intended nine-slice behavior.
