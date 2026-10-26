# Message Bubble Glass Action Menu — Our Own Version

This folder contains the project-owned adaptation of Swift Pieces Glass Action Menu. The upstream reference is preserved unchanged in the sibling `Source Code/` folder, which is read-only.

## Integration

The menu implementation is adapted in `GlassActionMenu.swift`; the host gesture adapter is `MessageBubbleActionMenuModifier.swift`. In the component package, these files are mirrored to:

- `Components/iOS/Imports/SwiftPiecesOriginals/Glass/Our Own Version/MessageBubbleGlassActionMenu.swift`
- `Components/iOS/MessageBubble/MessageBubbleActionMenuModifier.swift`

Usage:

```swift
MessageBubble(/* configuration */) {
    Text(messageText)
}
.messageBubbleActions(items: [
    .init(symbol: "doc.on.doc", label: "Copy") { copyMessage() },
    .init(symbol: "arrowshape.turn.up.left", label: "Reply") { replyToMessage() },
    .init(symbol: "heart", label: "React") { reactToMessage() }
])
```

The gesture is one continuous touch: hold for 350 ms, slide to an action, then release to fire it. Movement beyond the small pre-activation tolerance cancels activation so vertical scrolling can continue. `MessageBubble.swift` does not own menu state or choreography.

## License

The adaptation retains the upstream MIT + Commons Clause copyright and license header. App use is permitted; standalone resale, sublicensing, and redistribution of the component itself are restricted by the Commons Clause.
