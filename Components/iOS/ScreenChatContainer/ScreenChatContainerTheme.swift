import SwiftUI

/// Complete visual theme for the reusable chat container and its coordinated child components.
public struct ScreenChatContainerTheme: ScreenChatThemeProviding {
    public var container: ContainerAppearance { didSet { suppliedColors = nil; suppliedFonts = nil } }
    public var themeButton: ThemeButtonAppearance { didSet { suppliedColors = nil; suppliedFonts = nil } }
    public var sidebar: SidebarAppearance { didSet { suppliedColors = nil; suppliedFonts = nil } }
    private var baseScreenChat: ScreenChatConfig
    private var suppliedColors: ScreenChatThemeColors?
    private var suppliedFonts: ScreenChatThemeFonts?

    public var screenChat: ScreenChatConfig {
        get {
            var value = baseScreenChat
            value.themeColors = colors
            value.themeFonts = fonts
            return value
        }
        set {
            baseScreenChat = newValue
            suppliedColors = nil
            suppliedFonts = nil
        }
    }

    public var colors: ScreenChatThemeColors { suppliedColors ?? makeColors() }
    public var fonts: ScreenChatThemeFonts { suppliedFonts ?? makeFonts() }

    public init(
        container: ContainerAppearance = .default,
        themeButton: ThemeButtonAppearance = .default,
        sidebar: SidebarAppearance = .default,
        screenChat: ScreenChatConfig = .screenChat(colorScheme: .light)
    ) {
        self.container = container
        self.themeButton = themeButton
        self.sidebar = sidebar
        self.baseScreenChat = screenChat
        self.suppliedColors = nil
        self.suppliedFonts = nil
    }

    /// Creates a complete theme. Every required color and font token must be supplied explicitly.
    public init(colors: ScreenChatThemeColors, fonts: ScreenChatThemeFonts) {
        self.suppliedColors = colors
        self.suppliedFonts = fonts
        self.container = ContainerAppearance(
            background: colors.container.background,
            contentSurface: colors.container.contentSurface,
            separator: colors.container.separator,
            scrim: colors.container.modalScrim
        )
        self.themeButton = ThemeButtonAppearance(
            foreground: colors.themePicker.buttonForeground,
            background: colors.themePicker.buttonBackground,
            pressedBackground: colors.themePicker.buttonPressedBackground
        )
        self.sidebar = SidebarAppearance(
            background: colors.sidebar.background,
            header: .init(title: colors.sidebar.headerTitle, icon: colors.sidebar.headerIcon, newConversationForeground: colors.sidebar.newConversationIcon, newConversationBackground: colors.sidebar.newConversationBackground),
            search: .init(background: colors.sidebar.searchBackground, text: colors.sidebar.searchText, placeholder: colors.sidebar.searchPlaceholder, icon: colors.sidebar.searchIcon, border: colors.sidebar.searchBorder, font: fonts.sidebar.searchText, iconSize: fonts.sidebar.searchIconSize),
            sectionHeader: .init(text: colors.sidebar.sectionHeading),
            conversationRow: .init(primaryText: colors.sidebar.rowPrimary, secondaryText: colors.sidebar.rowSecondary, selectedBackground: colors.sidebar.rowSelectedBackground, selectedForeground: colors.sidebar.rowSelectedForeground, background: colors.sidebar.rowBackground),
            separator: colors.sidebar.rowSeparator,
            footer: .init(foreground: colors.sidebar.footerPrimary, secondaryForeground: colors.sidebar.footerSecondary, icon: colors.sidebar.footerIcon, background: colors.sidebar.footerBackground),
            typography: .init(headerTitle: fonts.sidebar.headerTitle, headerIconSize: fonts.sidebar.headerIconSize, newConversationIconSize: fonts.sidebar.newConversationIconSize, sectionHeading: fonts.sidebar.sectionHeading, rowPrimary: fonts.sidebar.rowPrimary, rowSecondary: fonts.sidebar.rowSecondary, footerPrimary: fonts.sidebar.footerPrimary, footerSecondary: fonts.sidebar.footerSecondary)
        )
        var messages = MessageChunk<AnyView>.Configuration.screenChat(colorScheme: .light)
        messages.incomingAvatar.placeholderStyle = .init(background: colors.chat.incomingAvatarBackground, foreground: colors.chat.incomingAvatarForeground)
        messages.outgoingAvatar.placeholderStyle = .init(background: colors.chat.outgoingAvatarBackground, foreground: colors.chat.outgoingAvatarForeground)
        messages.incomingBubble.fill = colors.chat.incomingBubbleFill
        messages.incomingBubble.border = colors.chat.incomingBubbleBorder
        messages.incomingBubble.timestampColor = colors.chat.incomingTimestamp
        messages.incomingBubble.font = fonts.chat.messageBody
        messages.incomingBubble.timestampFont = fonts.chat.messageTimestamp
        messages.outgoingBubble.fill = colors.chat.outgoingBubbleFill
        messages.outgoingBubble.border = colors.chat.outgoingBubbleBorder
        messages.outgoingBubble.timestampColor = colors.chat.outgoingTimestamp
        messages.outgoingBubble.font = fonts.chat.messageBody
        messages.outgoingBubble.timestampFont = fonts.chat.messageTimestamp
        messages.incomingTextColor = colors.chat.incomingMessageText
        messages.outgoingTextColor = colors.chat.outgoingMessageText
        self.baseScreenChat = ScreenChatConfig(
            background: colors.chat.background,
            headerBackground: colors.chat.headerSurface,
            separatorColor: colors.chat.separator,
            separatorOpacity: 1,
            titleColor: colors.chat.headerTitle,
            headerIconColor: colors.chat.headerIcon,
            subtitleColor: colors.chat.subtitle,
            onlineColor: colors.chat.onlineStatus,
            offlineColor: colors.chat.offlineStatus,
            dayLabelColor: colors.chat.dayLabelForeground,
            avatarPlaceholderBackground: colors.chat.incomingAvatarBackground,
            avatarPlaceholderForeground: colors.chat.incomingAvatarForeground,
            incomingMessageTextColor: colors.chat.incomingMessageText,
            outgoingMessageTextColor: colors.chat.outgoingMessageText,
            inputTextColor: colors.input.typedText,
            inputPlaceholderColor: colors.input.placeholder,
            inputIconColor: colors.input.utilityIcon,
            inputAccessoryButtonBackground: colors.input.utilityButtonBackground,
            inputAccessoryButtonForeground: colors.input.utilityButtonForeground,
            inputAccessoryIntersectionColor: colors.input.utilityIntersection,
            titleFont: fonts.chat.headerTitle,
            subtitleFont: fonts.chat.headerSubtitle,
            dayLabelFont: fonts.chat.dayLabel,
            inputAccessoryIconFont: .system(size: fonts.input.utilityIconSize, weight: .medium),
            messageConfiguration: messages,
            themeColors: colors,
            themeFonts: fonts
        )
    }

    public static func preset(_ preset: ScreenChatTheme, colorScheme: ColorScheme = .light) -> Self {
        let chat = ScreenChatThemes.configuration(for: preset, colorScheme: colorScheme)
        let palette: (background: Color, surface: Color, foreground: Color, secondary: Color, accent: Color, selected: Color, border: Color)
        switch preset {
        case .system:
            if colorScheme == .dark {
                palette = (Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground), .primary, .secondary, .accentColor, Color.primary.opacity(0.13), Color.primary.opacity(0.14))
            } else {
                palette = (Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground), .primary, .secondary, .accentColor, Color.primary.opacity(0.065), Color.primary.opacity(0.12))
            }
        case .midnight:
            palette = (Color(hex: 0x101116), Color(hex: 0x191A22), Color(hex: 0xF5F3FF), Color(hex: 0xAAA7BC), Color(hex: 0xC6A8FF), Color(hex: 0x302942), Color(hex: 0x777586).opacity(0.35))
        case .ocean:
            palette = (Color(hex: 0xF0F5FA), Color(hex: 0xE2ECF5), Color(hex: 0x203448), Color(hex: 0x63798C), Color(hex: 0x397DB8), Color(hex: 0xD6E8F7), Color(hex: 0x63798C).opacity(0.2))
        case .rose:
            palette = (Color(hex: 0xFFF0F4), Color(hex: 0xFFDDE7), Color(hex: 0x7A2448), Color(hex: 0xA64F73), Color(hex: 0xD94F82), Color(hex: 0xF8D0DF), Color(hex: 0xA64F73).opacity(0.2))
        case .forest:
            palette = (Color(hex: 0xF0F5F0), Color(hex: 0xE2ECE2), Color(hex: 0x233A2F), Color(hex: 0x6C8377), Color(hex: 0x397C62), Color(hex: 0xD7E8DA), Color(hex: 0x6C8377).opacity(0.2))
        case .dreamveil:
            palette = (Color.clear, Color.white.opacity(0.25), Color(hex: 0x51435F), Color(hex: 0x837493), Color(hex: 0x8068AA), Color.white.opacity(0.38), Color.white.opacity(0.64))
        case .sculpted:
            if colorScheme == .dark {
                palette = (Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground), .primary, .secondary, .accentColor, Color.primary.opacity(0.13), Color.primary.opacity(0.14))
            } else {
                palette = (Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground), .primary, .secondary, .accentColor, Color.primary.opacity(0.065), Color.primary.opacity(0.12))
            }
        }
        var result = Self(
            container: .init(background: palette.background, contentSurface: palette.background, separator: palette.border, scrim: .black.opacity(0.18)),
            themeButton: .init(foreground: palette.accent, background: palette.surface, pressedBackground: palette.selected),
            sidebar: .init(
                background: palette.background,
                header: .init(title: palette.foreground, icon: palette.accent, newConversationForeground: palette.accent, newConversationBackground: palette.surface),
                search: .init(background: palette.surface, text: palette.foreground, placeholder: palette.secondary, icon: palette.secondary, border: palette.border),
                sectionHeader: .init(text: palette.secondary),
                conversationRow: .init(primaryText: palette.foreground, secondaryText: palette.secondary, selectedBackground: palette.selected, selectedForeground: palette.foreground, background: .clear),
                separator: palette.border,
                footer: .init(foreground: palette.foreground, secondaryForeground: palette.secondary, icon: palette.accent, background: .clear)
            ),
            screenChat: chat
        )
        if preset == .dreamveil {
            result.sidebar.usesGlass = true
            result.baseScreenChat.usesGlassSurfaces = true
        }
        return result
    }

    public static func system(colorScheme: ColorScheme = .light) -> Self { preset(.system, colorScheme: colorScheme) }

    /// Complete, component-grouped token view derived from the authoritative scoped appearances.
    private func makeColors() -> ScreenChatThemeColors {
        let c = baseScreenChat
        let s = sidebar
        let input = c.inputIconColor
        return ScreenChatThemeColors(
            container: .init(background: container.background, contentSurface: container.contentSurface, separator: container.separator, modalScrim: container.scrim),
            themePicker: .init(buttonForeground: themeButton.foreground, buttonBackground: themeButton.background, buttonPressedBackground: themeButton.pressedBackground, sheetBackground: container.background, sheetSurface: container.contentSurface, presetTitle: c.titleColor, presetSubtitle: c.subtitleColor, presetSwatch: themeButton.foreground, selectedIndicator: themeButton.foreground, primaryAction: themeButton.foreground),
            sidebar: .init(background: s.background, headerTitle: s.header.title, headerIcon: s.header.icon, newConversationIcon: s.header.newConversationForeground, newConversationBackground: s.header.newConversationBackground, searchBackground: s.search.background, searchText: s.search.text, searchPlaceholder: s.search.placeholder, searchIcon: s.search.icon, searchBorder: s.search.border, sectionHeading: s.sectionHeader.text, rowPrimary: s.conversationRow.primaryText, rowSecondary: s.conversationRow.secondaryText, rowBackground: s.conversationRow.background, rowSelectedForeground: s.conversationRow.selectedForeground, rowSelectedBackground: s.conversationRow.selectedBackground, rowSeparator: s.separator, footerPrimary: s.footer.foreground, footerSecondary: s.footer.secondaryForeground, footerIcon: s.footer.icon, footerBackground: s.footer.background),
            messageList: .init(title: s.conversationRow.primaryText, subtitle: s.conversationRow.secondaryText),
            chat: .init(background: c.background, headerSurface: c.headerBackground, separator: c.separatorColor.opacity(c.separatorOpacity), headerTitle: c.titleColor, headerIcon: c.headerIconColor, subtitle: c.subtitleColor, onlineStatus: c.onlineColor, offlineStatus: c.offlineColor, dayLabelForeground: c.dayLabelColor, dayLabelSurface: container.contentSurface, incomingAvatarBackground: c.messageConfiguration.incomingAvatar.placeholderStyle.background, incomingAvatarForeground: c.messageConfiguration.incomingAvatar.placeholderStyle.foreground, outgoingAvatarBackground: c.messageConfiguration.outgoingAvatar.placeholderStyle.background, outgoingAvatarForeground: c.messageConfiguration.outgoingAvatar.placeholderStyle.foreground, incomingMessageText: c.incomingMessageTextColor, outgoingMessageText: c.outgoingMessageTextColor, incomingBubbleFill: c.messageConfiguration.incomingBubble.fill, incomingBubbleBorder: c.messageConfiguration.incomingBubble.border, incomingTimestamp: c.messageConfiguration.incomingBubble.timestampColor, outgoingBubbleFill: c.messageConfiguration.outgoingBubble.fill, outgoingBubbleBorder: c.messageConfiguration.outgoingBubble.border, outgoingTimestamp: c.messageConfiguration.outgoingBubble.timestampColor),
            input: .init(composerSurface: container.contentSurface, typedText: c.inputTextColor, placeholder: c.inputPlaceholderColor, utilityIcon: c.inputIconColor, utilityButtonBackground: c.inputAccessoryButtonBackground, utilityButtonForeground: c.inputAccessoryButtonForeground, utilityIntersection: c.inputAccessoryIntersectionColor, sendBackground: .primary, sendForeground: .white, stopBackground: .primary, stopForeground: .white, floatingSendBackground: .primary, floatingSendForeground: .white, floatingSendBorder: .none, actionPanelSurface: container.contentSurface, actionTileSurface: s.search.background, actionIcon: input, actionTitle: c.titleColor, actionSecondary: c.subtitleColor),
            stickerKeyboard: .init(panelBackground: container.contentSurface, topBorder: container.separator, categoryDivider: container.separator, categoryBarBackground: container.contentSurface, categoryIcon: input, selectedCategoryBackground: s.conversationRow.selectedBackground, selectedCategoryBorder: container.separator, loadingPlaceholder: s.search.background, failureIcon: c.offlineColor, emptyIcon: c.subtitleColor, emptyPrimary: c.titleColor, emptySecondary: c.subtitleColor, emojiPanelSurface: container.contentSurface, emojiSelectedSectionSurface: s.conversationRow.selectedBackground),
            stickerSearch: .init(surface: container.contentSurface, title: c.titleColor, secondary: c.subtitleColor, searchBackground: s.search.background, placeholder: s.search.placeholder, searchIcon: s.search.icon, selectionIcon: input, actionIcon: input, packTileSurface: s.search.background, packStateSurface: s.conversationRow.selectedBackground)
        )
    }

    private func makeFonts() -> ScreenChatThemeFonts {
        let c = baseScreenChat
        let s = sidebar
        return ScreenChatThemeFonts(
            container: .init(presetTitle: .body.weight(.medium), presetSubtitle: .caption, buttonSymbolSize: 17, selectedIndicatorSize: 19, navigationLabel: .body),
            sidebar: .init(headerTitle: s.typography.headerTitle, headerIconSize: s.typography.headerIconSize, newConversationIconSize: s.typography.newConversationIconSize, sectionHeading: s.typography.sectionHeading, rowPrimary: s.typography.rowPrimary, rowSecondary: s.typography.rowSecondary, footerPrimary: s.typography.footerPrimary, footerSecondary: s.typography.footerSecondary, searchText: s.search.font, searchIconSize: s.search.iconSize),
            messageList: .init(title: s.typography.rowPrimary, subtitle: s.typography.rowSecondary),
            chat: .init(headerTitle: c.titleFont, headerSubtitle: c.subtitleFont, dayLabel: c.dayLabelFont, messageBody: c.messageConfiguration.incomingBubble.font, messageTimestamp: c.messageConfiguration.incomingBubble.timestampFont, headerActionIconSize: 17),
            input: .init(textEntry: .system(size: 16), utilityIconSize: 24, sendIcon: .system(size: 16, weight: .semibold), stopIcon: .system(size: 13, weight: .semibold), floatingSendIcon: .system(size: 16), floatingSendIconSize: 16, actionIconSize: 22, actionTitle: .system(size: 12, weight: .medium)),
            stickerKeyboard: .init(emojiGlyphSize: 29, categoryIconSize: 18, emptyTitle: .headline, emptyBody: .subheadline),
            stickerSearch: .init(title: .headline, packTitle: .system(size: 15, weight: .semibold), metadata: .caption, searchField: .system(size: 15), actionLabel: .system(size: 13, weight: .medium), iconSize: 17)
        )
    }
}

public struct ContainerAppearance {
    public var background: Color
    public var contentSurface: Color
    public var separator: Color
    public var scrim: Color
    public init(background: Color = Color(uiColor: .systemBackground), contentSurface: Color = Color(uiColor: .systemBackground), separator: Color = Color.primary.opacity(0.12), scrim: Color = .black.opacity(0.18)) {
        self.background = background; self.contentSurface = contentSurface; self.separator = separator; self.scrim = scrim
    }
    public static let `default` = Self()
}

public struct ThemeButtonAppearance {
    public var foreground: Color
    public var background: Color
    public var pressedBackground: Color
    public init(foreground: Color = .secondary, background: Color = .clear, pressedBackground: Color = Color.primary.opacity(0.08)) {
        self.foreground = foreground; self.background = background; self.pressedBackground = pressedBackground
    }
    public static let `default` = Self()
}

public struct SidebarAppearance {
    public var background: Color
    public var header: Header
    public var search: Search
    public var sectionHeader: SectionHeader
    public var conversationRow: ConversationRow
    public var separator: Color
    public var footer: Footer
    public var typography: Typography
    public var usesGlass: Bool

    public init(background: Color = Color(uiColor: .secondarySystemBackground), usesGlass: Bool = false, header: Header = .default, search: Search = .default, sectionHeader: SectionHeader = .default, conversationRow: ConversationRow = .default, separator: Color = Color.primary.opacity(0.12), footer: Footer = .default, typography: Typography = .default) {
        self.background = background; self.usesGlass = usesGlass; self.header = header; self.search = search; self.sectionHeader = sectionHeader; self.conversationRow = conversationRow; self.separator = separator; self.footer = footer; self.typography = typography
    }
    public static let `default` = Self()

    public struct Header {
        public var title: Color; public var icon: Color; public var newConversationForeground: Color; public var newConversationBackground: Color
        public init(title: Color = .primary, icon: Color = .accentColor, newConversationForeground: Color = .primary, newConversationBackground: Color = Color(uiColor: .tertiarySystemFill)) { self.title = title; self.icon = icon; self.newConversationForeground = newConversationForeground; self.newConversationBackground = newConversationBackground }
        public static let `default` = Self()
    }
    public struct Search {
        public var background: Color; public var text: Color; public var placeholder: Color; public var icon: Color; public var border: Color
        public var font: Font; public var iconSize: CGFloat
        public init(background: Color = Color(uiColor: .tertiarySystemFill), text: Color = .primary, placeholder: Color = .secondary, icon: Color = .secondary, border: Color = .clear, font: Font = .system(size: 14), iconSize: CGFloat = 16) { self.background = background; self.text = text; self.placeholder = placeholder; self.icon = icon; self.border = border; self.font = font; self.iconSize = max(1, iconSize) }
        public static let `default` = Self()
    }
    public struct SectionHeader {
        public var text: Color
        public init(text: Color = .secondary) { self.text = text }
        public static let `default` = Self()
    }
    public struct ConversationRow {
        public var primaryText: Color; public var secondaryText: Color; public var selectedBackground: Color; public var selectedForeground: Color; public var background: Color
        public init(primaryText: Color = .primary, secondaryText: Color = .secondary, selectedBackground: Color = Color.primary.opacity(0.065), selectedForeground: Color = .primary, background: Color = .clear) { self.primaryText = primaryText; self.secondaryText = secondaryText; self.selectedBackground = selectedBackground; self.selectedForeground = selectedForeground; self.background = background }
        public static let `default` = Self()
    }
    public struct Footer {
        public var foreground: Color; public var secondaryForeground: Color; public var icon: Color; public var background: Color
        public init(foreground: Color = .primary, secondaryForeground: Color = .secondary, icon: Color = .secondary, background: Color = .clear) { self.foreground = foreground; self.secondaryForeground = secondaryForeground; self.icon = icon; self.background = background }
        public static let `default` = Self()
    }
    public struct Typography {
        public var headerTitle: Font; public var headerIconSize: CGFloat; public var newConversationIconSize: CGFloat
        public var sectionHeading: Font; public var rowPrimary: Font; public var rowSecondary: Font
        public var footerPrimary: Font; public var footerSecondary: Font
        public init(headerTitle: Font = .title2.weight(.bold), headerIconSize: CGFloat = 19, newConversationIconSize: CGFloat = 17, sectionHeading: Font = .caption.weight(.semibold), rowPrimary: Font = .system(size: 14), rowSecondary: Font = .system(size: 12), footerPrimary: Font = .subheadline.weight(.semibold), footerSecondary: Font = .caption) {
            self.headerTitle = headerTitle; self.headerIconSize = headerIconSize; self.newConversationIconSize = newConversationIconSize
            self.sectionHeading = sectionHeading; self.rowPrimary = rowPrimary; self.rowSecondary = rowSecondary
            self.footerPrimary = footerPrimary; self.footerSecondary = footerSecondary
        }
        public static let `default` = Self()
    }
}

private extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1) }
}
