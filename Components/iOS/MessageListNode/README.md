# MessageListNode

A reusable SwiftUI conversation-list row with an avatar, a person's name, and a latest-message preview.

## Example

```swift
MessageListNode(
    title: "Morgan Lee",
    subtitle: "Are we still meeting at six?",
    avatarImage: Image("morgan"),
    unreadCount: 8,
    onUnreadBadgeDismiss: { clearUnreadCount() },
    onDelete: { deleteConversation() },
    onMarkUnread: { markConversationUnread() }
)
```

## Customization

- `background` accepts the existing `Background` component. It defaults to `Background(color: .clear)`.
- `topBorder` and `bottomBorder` each accept an optional `AnyView`, so callers can pass `LineDashed` or another custom line view. `nil` renders no border and reserves no layout space. Give a border view its own frame where needed.
- `avatarImage` and `avatarPlaceholder` are rendered by the existing `Avatar` component. The default shape is a continuous rounded rectangle with a 6-point corner radius.
- `unreadCount` is passed to the existing `UnreadBadge` and displayed at the avatar’s top-right corner. A nil or zero count hides the badge; the badge formats counts above 99 as `99+`. `onUnreadBadgeDismiss` is called when the badge is dragged away, so the host can reset the count.
- Title and subtitle each support a custom `Font`, a system font size, a text color, and a maximum character count. Text exceeding its character limit is shortened with an ellipsis. A custom `Font` takes precedence over the size parameter.
- A leftward swipe reveals the configured delete and mark-as-unread actions using the reusable `SwipeActionRow` gesture implementation. Each action appears only when its callback is supplied. The host remains responsible for performing the actual data mutation.

The component does not own conversation models, navigation, persistence, read state, or list scrolling.
