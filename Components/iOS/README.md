# iOS Components

## SwipeActionRow

A reusable row that reveals configurable leading or trailing actions with rubber-band drag resistance and spring settling.

```swift
SwipeActionRow(actions: [
    SwipeRowAction("Delete", systemImage: "trash", tint: .red, role: .destructive) {
        deleteItem()
    },
    SwipeRowAction("Pin", systemImage: "pin.fill", tint: .blue) {
        pinItem()
    }
]) {
    MessageRowContent()
}
```

## FollowScrollView

A chat-oriented list that follows appended items when the reader is near the bottom and shows a “latest messages” affordance when new items arrive while the reader is browsing history.

```swift
struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
}

FollowScrollView(messages, id: \.id, spacing: 8) { message in
    Text(message.text)
        .frame(maxWidth: .infinity, alignment: .leading)
}
```

## ElasticButtonStyle

Import `Animated` and apply `.buttonStyle(.elastic)` to any SwiftUI `Button`. Use `.buttonStyle(.elastic(ElasticButtonConfiguration(...)))` to tune the press squash and release spring.

## NoticeStack

See [`Trivial/NoticeStack/README.md`](Trivial/NoticeStack/README.md) for the new standalone notification-card stack.
