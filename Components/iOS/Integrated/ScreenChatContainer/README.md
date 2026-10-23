# ScreenChatContainer

`ScreenChatContainer` is a layout shell, not a chat feature implementation. It owns the sidebar-open state, animation, and horizontal movement of one foreground content view. The sidebar is injected separately and remains underneath that moving view.

It deliberately does **not** import or construct `ScreenChat`, `HeaderChatScreen`, a chat model, or a recent-conversation list. That keeps the container portable across projects: consumers provide their own sidebar and content views.

## Example

```swift
ScreenChatContainer(
    sidebar: { closeSidebar in
        MyRecentChatsView(onSelectConversation: closeSidebar)
    },
    content: { toggleSidebar in
        ScreenChat(
            title: "Momo",
            onToggleSidebar: toggleSidebar
        )
    }
)
```

The sidebar receives a `closeSidebar` action for dismissing itself after a selection. The content view calls the supplied `toggleSidebar` action from its menu button. In this component library, `ScreenChat` forwards that action to `HeaderChatScreen`; other content views can use the same container without depending on either chat component.

The container provides the visual shell only. The host app remains responsible for conversation data, selection, persistence, and the behavior that should occur when a conversation is selected.
