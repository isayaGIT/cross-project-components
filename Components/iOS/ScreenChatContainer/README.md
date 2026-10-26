# ScreenChatContainer

`ScreenChatContainer` is a reusable layout shell. It owns sidebar-open state, animation, and the active coordinated theme; it does not own chat models, persistence, navigation, or sidebar data.

## Coordinated theme

The container's theme picker controls the entire composed appearance: the container shell, theme button, sidebar, and `ScreenChat` configuration. Five presets are available: System, Midnight, Ocean, Rose, and Forest.

```swift
ScreenChatContainer(
    theme: .preset(.ocean),
    sidebar: { closeSidebar, sidebarAppearance in
        Sidebar(
            conversations: conversations,
            selectedID: selectedID,
            appearance: sidebarAppearance,
            rowContent: { conversation, isSelected in
                ConversationRow(conversation, isSelected: isSelected)
            },
            onSelect: { conversation in
                select(conversation)
                closeSidebar()
            }
        )
    },
    content: { screenChatConfig, inputContext in
        ScreenChat(
            title: "Momo",
            configuration: screenChatConfig,
            inputContext: inputContext
        )
    }
)
```

`ScreenChatContainerTheme` conforms to `ScreenChatThemeProviding`. Its authoritative theme contract has exactly two sections, `colors` and `fonts`, grouped by the component that renders each value. Required nested token initializers have no default arguments, so a new theme cannot silently omit a required color or font.

To customize a preset while retaining its other tokens, copy both complete aggregates and pass them back to the concrete theme:

```swift
var colors = ScreenChatContainerTheme.preset(.ocean).colors
var fonts = ScreenChatContainerTheme.preset(.ocean).fonts
colors.sidebar.searchBackground = Color.blue.opacity(0.12)
colors.sidebar.searchBorder = Color.blue.opacity(0.25)
fonts.sidebar.searchText = .system(size: 15)

let theme = ScreenChatContainerTheme(colors: colors, fonts: fonts)
```

The older `container`, `themeButton`, `sidebar`, and `screenChat` appearance accessors remain as compatibility adapters. The built-in System, Midnight, Ocean, Rose, and Forest presets provide complete token aggregates. Selecting a preset in the picker replaces the active theme with that preset's complete values.

`SidebarAppearance` is organized by rendered region: `header`, `search`, `sectionHeader`, `conversationRow`, `separator`, and `footer`, plus the overall sidebar `background`. The reusable `Sidebar` and `SidebarSettingsEntry` consume these settings. Hosts using custom sidebar views must explicitly apply the provided `SidebarAppearance` to their own content; a generic SwiftUI container cannot recolor arbitrary child views automatically.

The content builder receives the `ScreenChatConfig` for the active overall theme and the coordinated input context. The container renders and owns the sidebar toggle button directly; the content does not need to receive a toggle callback. `ScreenChat` no longer owns a separate theme-selection state; its appearance comes from the supplied configuration. The host app still owns conversation data, selection, persistence, and feature actions.

The chat header's former settings action is the **Apps** launcher. `ScreenChat` presents `SheetApps` and reports the selected `ScreenChatApp` through `onOpenApp`; navigation remains host-owned. Global model-provider/API-key settings belong in the host-provided sidebar, such as its footer.
