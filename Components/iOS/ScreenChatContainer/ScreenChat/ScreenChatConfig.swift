import SwiftUI

/// Only the visual properties expected to vary between ScreenChat themes.
/// Structural defaults and component behavior remain in ScreenChat itself.
public struct ScreenChatConfig {
    // Theme colors and materials
    public var background: AnyShapeStyle
    public var headerBackground: AnyShapeStyle
    public var separatorColor: Color
    public var separatorOpacity: Double
    public var titleColor: Color
    public var headerIconColor: Color
    public var subtitleColor: Color
    public var onlineColor: Color
    public var offlineColor: Color
    public var dayLabelColor: Color
    public var avatarPlaceholderBackground: Color
    public var avatarPlaceholderForeground: Color
    public var incomingMessageTextColor: Color
    public var outgoingMessageTextColor: Color
    public var inputTextColor: Color
    public var inputPlaceholderColor: Color
    public var inputIconColor: Color
    public var inputAccessoryButtonBackground: Color
    public var inputAccessoryButtonForeground: Color
    public var inputAccessoryIntersectionColor: Color
    public var usesGlassSurfaces: Bool

    // Theme typography
    public var titleFont: Font
    public var subtitleFont: Font
    public var dayLabelFont: Font
    public var inputAccessoryIconFont: Font

    // Message appearance is delegated to MessageChunk's own configuration.
    public var messageConfiguration: MessageChunk<AnyView>.Configuration
    /// Complete token snapshot supplied by ScreenChatContainer; nil for standalone legacy use.
    public var themeColors: ScreenChatThemeColors?
    public var themeFonts: ScreenChatThemeFonts?

    public init(
        background: AnyShapeStyle = AnyShapeStyle(Color(uiColor: .systemBackground)),
        headerBackground: AnyShapeStyle = AnyShapeStyle(.bar),
        separatorColor: Color = .primary,
        separatorOpacity: Double = 0.12,
        titleColor: Color = .primary,
        headerIconColor: Color = .accentColor,
        subtitleColor: Color = .secondary,
        onlineColor: Color = .green,
        offlineColor: Color = .secondary.opacity(0.5),
        dayLabelColor: Color = .secondary,
        avatarPlaceholderBackground: Color = Color.accentColor.opacity(0.14),
        avatarPlaceholderForeground: Color = .accentColor,
        incomingMessageTextColor: Color = .primary,
        outgoingMessageTextColor: Color = .white,
        inputTextColor: Color = .primary,
        inputPlaceholderColor: Color = .secondary,
        inputIconColor: Color = .primary,
        inputAccessoryButtonBackground: Color = Color(uiColor: .tertiarySystemFill),
        inputAccessoryButtonForeground: Color = .primary,
        inputAccessoryIntersectionColor: Color = Color.primary.opacity(0.12),
        usesGlassSurfaces: Bool = false,
        titleFont: Font = .system(size: 16, weight: .semibold),
        subtitleFont: Font = .system(size: 12),
        dayLabelFont: Font = .system(size: 12, weight: .medium),
        inputAccessoryIconFont: Font = .system(size: 24, weight: .medium),
        messageConfiguration: MessageChunk<AnyView>.Configuration = .init(),
        themeColors: ScreenChatThemeColors? = nil,
        themeFonts: ScreenChatThemeFonts? = nil
    ) {
        self.background = background
        self.headerBackground = headerBackground
        self.separatorColor = separatorColor
        self.separatorOpacity = separatorOpacity
        self.titleColor = titleColor
        self.headerIconColor = headerIconColor
        self.subtitleColor = subtitleColor
        self.onlineColor = onlineColor
        self.offlineColor = offlineColor
        self.dayLabelColor = dayLabelColor
        self.avatarPlaceholderBackground = avatarPlaceholderBackground
        self.avatarPlaceholderForeground = avatarPlaceholderForeground
        self.incomingMessageTextColor = incomingMessageTextColor
        self.outgoingMessageTextColor = outgoingMessageTextColor
        self.inputTextColor = inputTextColor
        self.inputPlaceholderColor = inputPlaceholderColor
        self.inputIconColor = inputIconColor
        self.inputAccessoryButtonBackground = inputAccessoryButtonBackground
        self.inputAccessoryButtonForeground = inputAccessoryButtonForeground
        self.inputAccessoryIntersectionColor = inputAccessoryIntersectionColor
        self.usesGlassSurfaces = usesGlassSurfaces
        self.titleFont = titleFont
        self.subtitleFont = subtitleFont
        self.dayLabelFont = dayLabelFont
        self.inputAccessoryIconFont = inputAccessoryIconFont
        self.messageConfiguration = messageConfiguration
        self.themeColors = themeColors
        self.themeFonts = themeFonts
    }

    /// Theme-aware default matching ScreenChat's built-in appearance.
    public static func screenChat(colorScheme: ColorScheme) -> Self {
        var config = Self()
        config.messageConfiguration = .screenChat(colorScheme: colorScheme)
        return config
    }
}
