# MessageBubble

A small, native SwiftUI building block for chat message bubbles. It draws the bubble as one continuous shape with a configurable square corner; it does **not** append a separate triangle or tail.

## Scope

- `MessageBubbleShape` owns only bubble geometry and can be used independently with SwiftUI shape APIs.
- `MessageBubble<Content>` adds a fill, configurable content padding, and optional outer width/height around caller-provided SwiftUI content.
- The host app owns message data, sender layout, typography, accessibility labels for message content, delivery state, animations, shadows, borders, and interaction behavior.
- No chat timeline, message model, networking, theme engine, effect framework, or third-party dependency is included.

## Requirements

Swift 5.9+, iOS 17+ (the package's existing iOS deployment target). The component uses `UnevenRoundedRectangle` with continuous corners.

## Usage

```swift
import SwiftUI

struct ExampleMessage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MessageBubble(sharpCorner: .bottomLeading, fill: Color.gray.opacity(0.16)) {
                Text("An incoming message")
                    .font(.custom("YourAppFont-Medium", size: 16))
                    .foregroundStyle(.primary)
            }

            MessageBubble(
                cornerRadius: 20,
                sharpCorner: .bottomTrailing,
                fill: LinearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ) {
                Text("An outgoing message")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
    }
}
```

For a shape-only use case:

```swift
MessageBubbleShape(cornerRadius: 18, sharpCorner: .bottomTrailing)
    .fill(.blue)
    .frame(width: 220, height: 84)
```

## Public API

| API | Behavior |
| --- | --- |
| `MessageBubbleShape(cornerRadius:sharpCorner:)` | Reusable geometry with a non-negative radius; oversized radii are clamped to the shape's bounds. |
| `SharpCorner.none` | All four corners use the configured radius. |
| `SharpCorner.topLeading`, `.topTrailing`, `.bottomLeading`, `.bottomTrailing` | The selected corner is square; the other three remain rounded. Leading/trailing follow SwiftUI's layout direction. |
| `MessageBubble(..., fill: ...)` | Accepts any `ShapeStyle`, including `Color`, material-compatible styles, and gradients. |
| `padding`, `width`, `height`, `alignment` | Control content inset and optional bubble dimensions. `nil` dimensions preserve content-driven sizing. |
| Content closure | Accepts any SwiftUI view. Set fonts, text colors, accessibility behavior, and content-specific styling on the content itself. |

## Design decisions

- **No appended tail:** the silhouette is a single path, so the square corner is part of the bubble itself.
- **Shape and view are separate:** geometry is independently reusable and can be tested without coupling it to text or message state.
- **SwiftUI-native customization:** font, shadow, stroke, animation, and other effects remain standard view modifiers. This avoids an effect registry or a parallel styling abstraction.
- **No global design-token dependency:** a reusable primitive should not silently impose one app's palette or typography. The default fill uses `Color.accentColor`; consumers can supply their own style.
- **No hard-coded text layout:** the component accepts arbitrary content, and custom fonts remain the host app's responsibility.
