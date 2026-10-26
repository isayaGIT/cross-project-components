import SwiftUI

/// Built-in appearance presets available from ScreenChat's theme picker.
public enum ScreenChatTheme: String, CaseIterable, Identifiable {
    case system
    case midnight
    case ocean
    case rose
    case forest
    case dreamveil
    case sculpted

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .midnight: "午夜紫"
        case .ocean: "海盐蓝"
        case .rose: "樱花粉"
        case .forest: "森林绿"
        case .dreamveil: "梦境柔光"
        case .sculpted: "珍珠浮雕"
        }
    }

    var subtitle: String {
        switch self {
        case .system: "使用当前系统外观"
        case .midnight: "深色背景与紫色气泡"
        case .ocean: "清爽蓝灰与海洋蓝"
        case .rose: "柔和暖白与玫瑰粉"
        case .forest: "自然墨绿与薄荷色"
        case .dreamveil: "朦胧云雾与悬浮毛玻璃"
        case .sculpted: "带有立体厚度与柔和投影的消息气泡"
        }
    }

    var symbol: String {
        switch self {
        case .system: "iphone"
        case .midnight: "moon.stars.fill"
        case .ocean: "water.waves"
        case .rose: "heart.fill"
        case .forest: "leaf.fill"
        case .dreamveil: "sparkles"
        case .sculpted: "square.3.layers.3d"
        }
    }
}

public enum ScreenChatThemes {
    /// Creates the selected theme while preserving ScreenChat's shared layout and behavior.
    public static func configuration(for theme: ScreenChatTheme, colorScheme: ColorScheme = .light) -> ScreenChatConfig {
        switch theme {
        case .system:
            return .screenChat(colorScheme: colorScheme)
        case .midnight:
            return midnight(colorScheme: .dark)
        case .ocean:
            return coloredTheme(
                background: 0xF0F5FA, header: 0xE2ECF5, incoming: 0xFFFFFF,
                outgoing: 0x397DB8, primaryText: 0x203448, secondaryText: 0x63798C,
                accent: 0x397DB8, avatarBackground: 0xD6E8F7, avatarForeground: 0x2C6DAB,
                colorScheme: .light
            )
        case .rose:
            return coloredTheme(
                background: 0xFFF0F4, header: 0xFFDDE7, incoming: 0xFFE4EC,
                outgoing: 0xD94F82, primaryText: 0x7A2448, secondaryText: 0xA64F73,
                accent: 0xD94F82, avatarBackground: 0xF8D0DF, avatarForeground: 0xB72F68,
                colorScheme: .light
            )
        case .forest:
            return coloredTheme(
                background: 0xF0F5F0, header: 0xE2ECE2, incoming: 0xFFFFFF,
                outgoing: 0x397C62, primaryText: 0x233A2F, secondaryText: 0x6C8377,
                accent: 0x397C62, avatarBackground: 0xD7E8DA, avatarForeground: 0x2F6B50,
                colorScheme: .light
            )
        case .dreamveil:
            return dreamveilConfiguration()
        case .sculpted:
            // Start from the ordinary system appearance, not Dreamveil's glass treatment.
            var theme = ScreenChatConfig.screenChat(colorScheme: colorScheme)
            var messages = theme.messageConfiguration
            let relief = MessageBubbleTheme(usesCardGeneral: true, cardGeneralThickness: 6, cardGeneralPalette: colorScheme == .dark ? .graphite : .pearl)
            messages.incomingBubble.theme = relief
            messages.outgoingBubble.theme = relief
            theme.messageConfiguration = messages
            return theme
        }
    }

    private static func dreamveilConfiguration() -> ScreenChatConfig {
            var theme = ScreenChatConfig.screenChat(colorScheme: .light)
            theme.background = AnyShapeStyle(Color.clear)
            theme.headerBackground = AnyShapeStyle(.ultraThinMaterial)
            theme.separatorColor = Color.white
            theme.separatorOpacity = 0.42
            theme.titleColor = Color(hex: 0x4D3D65)
            theme.headerIconColor = Color(hex: 0x8A70B5)
            theme.subtitleColor = Color(hex: 0x837493)
            theme.onlineColor = Color(hex: 0x5BAF9A)
            theme.offlineColor = Color(hex: 0x9C8DA8)
            theme.dayLabelColor = Color(hex: 0x665878)
            theme.avatarPlaceholderBackground = Color.white.opacity(0.48)
            theme.avatarPlaceholderForeground = Color(hex: 0x8A70B5)
            theme.incomingMessageTextColor = Color(hex: 0x51435F)
            theme.outgoingMessageTextColor = Color(hex: 0x51435F)
            theme.inputTextColor = Color(hex: 0x51435F)
            theme.inputPlaceholderColor = Color(hex: 0x8A7D99)
            theme.inputIconColor = Color(hex: 0x8068AA)
            theme.inputAccessoryButtonBackground = Color.white.opacity(0.12)
            theme.inputAccessoryButtonForeground = Color(hex: 0x8068AA)
            theme.inputAccessoryIntersectionColor = Color.white.opacity(0.32)
            var messages = MessageChunk<AnyView>.Configuration.screenChat(colorScheme: .light)
            messages.incomingBubble.style = .tailLess
            messages.incomingBubble.sharpCorner = .bottomLeading
            messages.incomingBubble.fill = AnyShapeStyle(.ultraThinMaterial)
            messages.incomingBubble.border = .solid(color: Color.white.opacity(0.7), lineWidth: 1)
            messages.incomingBubble.timestampColor = Color(hex: 0x837493)
            messages.incomingBubble.font = .system(size: 16)
            messages.outgoingBubble.style = .tailLess
            messages.outgoingBubble.sharpCorner = .bottomTrailing
            messages.outgoingBubble.fill = AnyShapeStyle(.thinMaterial)
            messages.outgoingBubble.border = .solid(color: Color.white.opacity(0.82), lineWidth: 1)
            messages.outgoingBubble.timestampColor = Color(hex: 0x8068AA)
            messages.outgoingBubble.font = .system(size: 16)
            messages.incomingTextColor = theme.incomingMessageTextColor
            messages.outgoingTextColor = theme.outgoingMessageTextColor
            theme.messageConfiguration = messages
            theme.usesGlassSurfaces = true
            return theme
    }

    /// Backward-compatible public preset retained for callers already using this API.
    public static func midnight(colorScheme: ColorScheme = .dark) -> ScreenChatConfig {
        var theme = ScreenChatConfig.screenChat(colorScheme: colorScheme)
        theme.background = AnyShapeStyle(Color(hex: 0x101116))
        theme.headerBackground = AnyShapeStyle(Color(hex: 0x191A22))
        theme.separatorColor = Color(hex: 0xFFFFFF)
        theme.separatorOpacity = 0.09
        theme.titleColor = Color(hex: 0xF5F3FF)
        theme.headerIconColor = Color(hex: 0xD8C9F5)
        theme.subtitleColor = Color(hex: 0xAAA7BC)
        theme.onlineColor = Color(hex: 0x54D99A)
        theme.offlineColor = Color(hex: 0x777586)
        theme.dayLabelColor = Color(hex: 0xAAA7BC)
        theme.avatarPlaceholderBackground = Color(hex: 0x302942)
        theme.avatarPlaceholderForeground = Color(hex: 0xC6A8FF)
        theme.incomingMessageTextColor = Color(hex: 0xF1EFF8)
        theme.outgoingMessageTextColor = Color(hex: 0xFFFFFF)
        theme.inputTextColor = Color(hex: 0xF5F3FF)
        theme.inputPlaceholderColor = Color(hex: 0xAAA7BC)
        theme.inputIconColor = Color(hex: 0xD8C9F5)
        theme.inputAccessoryButtonBackground = Color(hex: 0x292631)
        theme.inputAccessoryButtonForeground = Color(hex: 0xD8C9F5)
        theme.inputAccessoryIntersectionColor = Color(hex: 0x7651C9)

        var messages = MessageChunk<AnyView>.Configuration.screenChat(colorScheme: .dark)
        messages.incomingAvatar.placeholderStyle = .init(background: Color(hex: 0x302942), foreground: Color(hex: 0xC6A8FF))
        messages.outgoingAvatar.placeholderStyle = .init(background: Color(hex: 0x3D3157), foreground: Color(hex: 0xE7DDFB))
        messages.incomingBubble.fill = AnyShapeStyle(Color(hex: 0x252630))
        messages.incomingBubble.timestampColor = Color(hex: 0xAAA7BC)
        messages.incomingBubble.font = .system(size: 16)
        messages.incomingBubble.border = .dashed(fill: .color(Color(hex: 0x7B748E).opacity(0.8)))
        messages.outgoingBubble.fill = AnyShapeStyle(Color(hex: 0x7651C9))
        messages.outgoingBubble.timestampColor = Color(hex: 0xE7DDFB)
        messages.outgoingBubble.font = .system(size: 16)
        messages.outgoingBubble.border = .dashed(fill: .color(Color(hex: 0xE7DDFB).opacity(0.95)))
        messages.incomingTextColor = theme.incomingMessageTextColor
        messages.outgoingTextColor = theme.outgoingMessageTextColor
        theme.messageConfiguration = messages
        return theme
    }

    static func previewColor(for theme: ScreenChatTheme) -> Color {
        switch theme {
        case .system: Color.accentColor
        case .midnight: Color(hex: 0x7651C9)
        case .ocean: Color(hex: 0x397DB8)
        case .rose: Color(hex: 0xD66B89)
        case .forest: Color(hex: 0x397C62)
        case .dreamveil: Color(hex: 0xA99BD7)
        case .sculpted: Color(hex: 0xD7C9B5)
        }
    }

    private static func coloredTheme(
        background: UInt32, header: UInt32, incoming: UInt32, outgoing: UInt32,
        primaryText: UInt32, secondaryText: UInt32, accent: UInt32,
        avatarBackground: UInt32, avatarForeground: UInt32, colorScheme: ColorScheme
    ) -> ScreenChatConfig {
        var theme = ScreenChatConfig.screenChat(colorScheme: colorScheme)
        theme.background = AnyShapeStyle(Color(hex: background))
        theme.headerBackground = AnyShapeStyle(Color(hex: header))
        theme.separatorColor = Color(hex: primaryText)
        theme.separatorOpacity = 0.1
        theme.titleColor = Color(hex: primaryText)
        theme.headerIconColor = Color(hex: accent)
        theme.subtitleColor = Color(hex: secondaryText)
        theme.dayLabelColor = Color(hex: secondaryText)
        theme.avatarPlaceholderBackground = Color(hex: avatarBackground)
        theme.avatarPlaceholderForeground = Color(hex: avatarForeground)
        theme.incomingMessageTextColor = Color(hex: primaryText)
        theme.outgoingMessageTextColor = Color(hex: 0xFFF3F7)
        theme.inputTextColor = Color(hex: primaryText)
        theme.inputPlaceholderColor = Color(hex: secondaryText)
        theme.inputIconColor = Color(hex: accent)
        theme.inputAccessoryButtonBackground = Color(hex: header)
        theme.inputAccessoryButtonForeground = Color(hex: accent)
        theme.inputAccessoryIntersectionColor = Color(hex: accent).opacity(0.24)

        var messages = MessageChunk<AnyView>.Configuration.screenChat(colorScheme: colorScheme)
        messages.incomingAvatar.placeholderStyle = .init(background: Color(hex: avatarBackground), foreground: Color(hex: avatarForeground))
        messages.outgoingAvatar.placeholderStyle = .init(background: Color(hex: avatarBackground).opacity(0.72), foreground: Color(hex: accent))
        messages.incomingBubble.fill = AnyShapeStyle(Color(hex: incoming))
        messages.incomingBubble.timestampColor = Color(hex: accent)
        messages.incomingBubble.font = .system(size: 16)
        messages.incomingBubble.border = .dashed(fill: .color(Color(hex: accent).opacity(0.8)))
        messages.outgoingBubble.fill = AnyShapeStyle(Color(hex: outgoing))
        messages.outgoingBubble.timestampColor = Color(hex: 0xFFE3ED)
        messages.outgoingBubble.font = .system(size: 16)
        messages.outgoingBubble.border = .dashed(fill: .color(Color(hex: accent).opacity(0.95)))
        messages.incomingTextColor = theme.incomingMessageTextColor
        messages.outgoingTextColor = theme.outgoingMessageTextColor
        theme.messageConfiguration = messages
        return theme
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
