# ScreenChat

`ScreenChat.swift` owns stable layout and interaction defaults. `ScreenChatConfig.swift` contains only theme-level values that are expected to change between visual styles: colors, materials, typography, avatar placeholder colors, and message appearance.

## Theme usage

The chat header includes a palette button that opens the built-in theme picker. Users can switch between **跟随系统**, **午夜紫**, **海盐蓝**, **樱花粉**, and **森林绿**; the selected preset updates the chat background, header, avatar placeholders, and message bubbles immediately. The default remains system appearance, and a caller-supplied `configuration` continues to be used until the user selects a preset.

A ready-made example theme is also available to callers in `ScreenChatThemes.swift`. Use it like this:

```swift
ScreenChat(
    title: "Momo",
    subtitle: "在线",
    configuration: ScreenChatThemes.midnight()
)
```

To create another theme, add a preset that starts with `ScreenChatConfig.screenChat(colorScheme:)`, then override only the appearance values you want to change:

```swift
public static func ocean(colorScheme: ColorScheme = .dark) -> ScreenChatConfig {
    var theme = ScreenChatConfig.screenChat(colorScheme: colorScheme)
    theme.background = AnyShapeStyle(Color(red: 0.04, green: 0.09, blue: 0.15))
    theme.titleColor = .white
    theme.onlineColor = .mint

    var messages = MessageChunk<AnyView>.Configuration.screenChat(colorScheme: colorScheme)
    messages.outgoingBubble.fill = AnyShapeStyle(Color.cyan)
    theme.messageConfiguration = messages
    return theme
}
```

Pass no configuration to use the built-in appearance. Keep stable structural decisions (header dimensions, paddings, timeline spacing, composer layout, and behavior) in `ScreenChat.swift`; use `ScreenChatConfig` for theme variations only. Screen content, messages, avatars, and callbacks remain explicit `ScreenChat` inputs.
