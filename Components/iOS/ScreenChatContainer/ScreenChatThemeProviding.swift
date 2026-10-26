import SwiftUI

/// Complete theme contract for the built-in ScreenChat composition.
public protocol ScreenChatThemeProviding {
    var colors: ScreenChatThemeColors { get }
    var fonts: ScreenChatThemeFonts { get }
}

/// Required colors grouped by the component that renders them. Initializers intentionally have no defaults.
public struct ScreenChatThemeColors {
    public var container: Container
    public var themePicker: ThemePicker
    public var sidebar: Sidebar
    public var messageList: MessageList
    public var chat: Chat
    public var input: Input
    public var stickerKeyboard: StickerKeyboard
    public var stickerSearch: StickerSearch

    public init(container: Container, themePicker: ThemePicker, sidebar: Sidebar, messageList: MessageList, chat: Chat, input: Input, stickerKeyboard: StickerKeyboard, stickerSearch: StickerSearch) {
        self.container = container; self.themePicker = themePicker; self.sidebar = sidebar; self.messageList = messageList; self.chat = chat
        self.input = input; self.stickerKeyboard = stickerKeyboard; self.stickerSearch = stickerSearch
    }

    public struct Container {
        public var background, contentSurface, separator, modalScrim: Color
        public init(background: Color, contentSurface: Color, separator: Color, modalScrim: Color) {
            self.background = background; self.contentSurface = contentSurface; self.separator = separator; self.modalScrim = modalScrim
        }
    }
    public struct ThemePicker {
        public var buttonForeground, buttonBackground, buttonPressedBackground, sheetBackground, sheetSurface: Color
        public var presetTitle, presetSubtitle, presetSwatch, selectedIndicator, primaryAction: Color
        public init(buttonForeground: Color, buttonBackground: Color, buttonPressedBackground: Color, sheetBackground: Color, sheetSurface: Color, presetTitle: Color, presetSubtitle: Color, presetSwatch: Color, selectedIndicator: Color, primaryAction: Color) {
            self.buttonForeground = buttonForeground; self.buttonBackground = buttonBackground; self.buttonPressedBackground = buttonPressedBackground
            self.sheetBackground = sheetBackground; self.sheetSurface = sheetSurface; self.presetTitle = presetTitle; self.presetSubtitle = presetSubtitle
            self.presetSwatch = presetSwatch; self.selectedIndicator = selectedIndicator; self.primaryAction = primaryAction
        }
    }
    public struct Sidebar {
        public var background, headerTitle, headerIcon, newConversationIcon, newConversationBackground: Color
        public var searchBackground, searchText, searchPlaceholder, searchIcon, searchBorder: Color
        public var sectionHeading, rowPrimary, rowSecondary, rowBackground, rowSelectedForeground, rowSelectedBackground, rowSeparator: Color
        public var footerPrimary, footerSecondary, footerIcon, footerBackground: Color
        public init(background: Color, headerTitle: Color, headerIcon: Color, newConversationIcon: Color, newConversationBackground: Color, searchBackground: Color, searchText: Color, searchPlaceholder: Color, searchIcon: Color, searchBorder: Color, sectionHeading: Color, rowPrimary: Color, rowSecondary: Color, rowBackground: Color, rowSelectedForeground: Color, rowSelectedBackground: Color, rowSeparator: Color, footerPrimary: Color, footerSecondary: Color, footerIcon: Color, footerBackground: Color) {
            self.background = background; self.headerTitle = headerTitle; self.headerIcon = headerIcon; self.newConversationIcon = newConversationIcon; self.newConversationBackground = newConversationBackground
            self.searchBackground = searchBackground; self.searchText = searchText; self.searchPlaceholder = searchPlaceholder; self.searchIcon = searchIcon; self.searchBorder = searchBorder
            self.sectionHeading = sectionHeading; self.rowPrimary = rowPrimary; self.rowSecondary = rowSecondary; self.rowBackground = rowBackground; self.rowSelectedForeground = rowSelectedForeground; self.rowSelectedBackground = rowSelectedBackground; self.rowSeparator = rowSeparator
            self.footerPrimary = footerPrimary; self.footerSecondary = footerSecondary; self.footerIcon = footerIcon; self.footerBackground = footerBackground
        }
    }
    public struct MessageList {
        public var title, subtitle: Color
        public init(title: Color, subtitle: Color) {
            self.title = title; self.subtitle = subtitle
        }
    }
    public struct Chat {
        public var background, headerSurface: AnyShapeStyle
        public var separator, headerTitle, headerIcon, subtitle, onlineStatus, offlineStatus: Color
        public var dayLabelForeground, dayLabelSurface, incomingAvatarBackground, incomingAvatarForeground, outgoingAvatarBackground, outgoingAvatarForeground: Color
        public var incomingMessageText, outgoingMessageText, incomingTimestamp, outgoingTimestamp: Color
        public var incomingBubbleFill, outgoingBubbleFill: AnyShapeStyle
        public var incomingBubbleBorder, outgoingBubbleBorder: MessageBubbleBorder
        public init(background: AnyShapeStyle, headerSurface: AnyShapeStyle, separator: Color, headerTitle: Color, headerIcon: Color, subtitle: Color, onlineStatus: Color, offlineStatus: Color, dayLabelForeground: Color, dayLabelSurface: Color, incomingAvatarBackground: Color, incomingAvatarForeground: Color, outgoingAvatarBackground: Color, outgoingAvatarForeground: Color, incomingMessageText: Color, outgoingMessageText: Color, incomingBubbleFill: AnyShapeStyle, incomingBubbleBorder: MessageBubbleBorder, incomingTimestamp: Color, outgoingBubbleFill: AnyShapeStyle, outgoingBubbleBorder: MessageBubbleBorder, outgoingTimestamp: Color) {
            self.background = background; self.headerSurface = headerSurface; self.separator = separator; self.headerTitle = headerTitle; self.headerIcon = headerIcon; self.subtitle = subtitle; self.onlineStatus = onlineStatus; self.offlineStatus = offlineStatus
            self.dayLabelForeground = dayLabelForeground; self.dayLabelSurface = dayLabelSurface; self.incomingAvatarBackground = incomingAvatarBackground; self.incomingAvatarForeground = incomingAvatarForeground; self.outgoingAvatarBackground = outgoingAvatarBackground; self.outgoingAvatarForeground = outgoingAvatarForeground
            self.incomingMessageText = incomingMessageText; self.outgoingMessageText = outgoingMessageText; self.incomingBubbleFill = incomingBubbleFill; self.incomingBubbleBorder = incomingBubbleBorder; self.incomingTimestamp = incomingTimestamp
            self.outgoingBubbleFill = outgoingBubbleFill; self.outgoingBubbleBorder = outgoingBubbleBorder; self.outgoingTimestamp = outgoingTimestamp
        }
    }
    public struct Input {
        public var composerSurface, typedText, placeholder, utilityIcon, sendBackground, sendForeground, stopBackground, stopForeground: Color
        public var utilityButtonBackground, utilityButtonForeground, utilityIntersection: Color
        public var floatingSendBackground, floatingSendForeground, actionPanelSurface, actionTileSurface, actionIcon, actionTitle, actionSecondary: Color
        public var floatingSendBorder: CapsuleButtonBorder
        public init(composerSurface: Color, typedText: Color, placeholder: Color, utilityIcon: Color, utilityButtonBackground: Color, utilityButtonForeground: Color, utilityIntersection: Color, sendBackground: Color, sendForeground: Color, stopBackground: Color, stopForeground: Color, floatingSendBackground: Color, floatingSendForeground: Color, floatingSendBorder: CapsuleButtonBorder, actionPanelSurface: Color, actionTileSurface: Color, actionIcon: Color, actionTitle: Color, actionSecondary: Color) {
            self.composerSurface = composerSurface; self.typedText = typedText; self.placeholder = placeholder; self.utilityIcon = utilityIcon; self.sendBackground = sendBackground; self.sendForeground = sendForeground; self.stopBackground = stopBackground; self.stopForeground = stopForeground
            self.utilityButtonBackground = utilityButtonBackground; self.utilityButtonForeground = utilityButtonForeground; self.utilityIntersection = utilityIntersection
            self.floatingSendBackground = floatingSendBackground; self.floatingSendForeground = floatingSendForeground; self.floatingSendBorder = floatingSendBorder; self.actionPanelSurface = actionPanelSurface; self.actionTileSurface = actionTileSurface; self.actionIcon = actionIcon; self.actionTitle = actionTitle; self.actionSecondary = actionSecondary
        }
    }
    public struct StickerKeyboard {
        public var panelBackground, topBorder, categoryDivider, categoryBarBackground, categoryIcon, selectedCategoryBackground, selectedCategoryBorder: Color
        public var loadingPlaceholder, failureIcon, emptyIcon, emptyPrimary, emptySecondary, emojiPanelSurface, emojiSelectedSectionSurface: Color
        public init(panelBackground: Color, topBorder: Color, categoryDivider: Color, categoryBarBackground: Color, categoryIcon: Color, selectedCategoryBackground: Color, selectedCategoryBorder: Color, loadingPlaceholder: Color, failureIcon: Color, emptyIcon: Color, emptyPrimary: Color, emptySecondary: Color, emojiPanelSurface: Color, emojiSelectedSectionSurface: Color) {
            self.panelBackground = panelBackground; self.topBorder = topBorder; self.categoryDivider = categoryDivider; self.categoryBarBackground = categoryBarBackground; self.categoryIcon = categoryIcon; self.selectedCategoryBackground = selectedCategoryBackground; self.selectedCategoryBorder = selectedCategoryBorder
            self.loadingPlaceholder = loadingPlaceholder; self.failureIcon = failureIcon; self.emptyIcon = emptyIcon; self.emptyPrimary = emptyPrimary; self.emptySecondary = emptySecondary; self.emojiPanelSurface = emojiPanelSurface; self.emojiSelectedSectionSurface = emojiSelectedSectionSurface
        }
    }
    public struct StickerSearch {
        public var surface, title, secondary, searchBackground, placeholder, searchIcon, selectionIcon, actionIcon, packTileSurface, packStateSurface: Color
        public init(surface: Color, title: Color, secondary: Color, searchBackground: Color, placeholder: Color, searchIcon: Color, selectionIcon: Color, actionIcon: Color, packTileSurface: Color, packStateSurface: Color) {
            self.surface = surface; self.title = title; self.secondary = secondary; self.searchBackground = searchBackground; self.placeholder = placeholder; self.searchIcon = searchIcon; self.selectionIcon = selectionIcon; self.actionIcon = actionIcon; self.packTileSurface = packTileSurface; self.packStateSurface = packStateSurface
        }
    }
}

/// Required typography tokens; icon sizes are explicit scalar values.
public struct ScreenChatThemeFonts {
    public var container: Container; public var sidebar: Sidebar; public var messageList: MessageList; public var chat: Chat; public var input: Input; public var stickerKeyboard: StickerKeyboard; public var stickerSearch: StickerSearch
    public init(container: Container, sidebar: Sidebar, messageList: MessageList, chat: Chat, input: Input, stickerKeyboard: StickerKeyboard, stickerSearch: StickerSearch) {
        self.container = container; self.sidebar = sidebar; self.messageList = messageList; self.chat = chat; self.input = input; self.stickerKeyboard = stickerKeyboard; self.stickerSearch = stickerSearch
    }
    public struct Container {
        public var presetTitle, presetSubtitle, navigationLabel: Font
        public var buttonSymbolSize, selectedIndicatorSize: CGFloat
        public init(presetTitle: Font, presetSubtitle: Font, buttonSymbolSize: CGFloat, selectedIndicatorSize: CGFloat, navigationLabel: Font) {
            self.presetTitle = presetTitle; self.presetSubtitle = presetSubtitle; self.buttonSymbolSize = buttonSymbolSize; self.selectedIndicatorSize = selectedIndicatorSize; self.navigationLabel = navigationLabel
        }
    }
    public struct Sidebar {
        public var headerTitle, sectionHeading, rowPrimary, rowSecondary, footerPrimary, footerSecondary, searchText: Font
        public var headerIconSize, newConversationIconSize, searchIconSize: CGFloat
        public init(headerTitle: Font, headerIconSize: CGFloat, newConversationIconSize: CGFloat, sectionHeading: Font, rowPrimary: Font, rowSecondary: Font, footerPrimary: Font, footerSecondary: Font, searchText: Font, searchIconSize: CGFloat) {
            self.headerTitle = headerTitle; self.headerIconSize = headerIconSize; self.newConversationIconSize = newConversationIconSize; self.sectionHeading = sectionHeading; self.rowPrimary = rowPrimary; self.rowSecondary = rowSecondary; self.footerPrimary = footerPrimary; self.footerSecondary = footerSecondary; self.searchText = searchText; self.searchIconSize = searchIconSize
        }
    }
    public struct MessageList {
        public var title, subtitle: Font
        public init(title: Font, subtitle: Font) {
            self.title = title; self.subtitle = subtitle
        }
    }
    public struct Chat {
        public var headerTitle, headerSubtitle, dayLabel, messageBody, messageTimestamp: Font
        public var headerActionIconSize: CGFloat
        public init(headerTitle: Font, headerSubtitle: Font, dayLabel: Font, messageBody: Font, messageTimestamp: Font, headerActionIconSize: CGFloat) {
            self.headerTitle = headerTitle; self.headerSubtitle = headerSubtitle; self.dayLabel = dayLabel; self.messageBody = messageBody; self.messageTimestamp = messageTimestamp; self.headerActionIconSize = headerActionIconSize
        }
    }
    public struct Input {
        public var textEntry, sendIcon, stopIcon, floatingSendIcon, actionTitle: Font
        public var utilityIconSize, floatingSendIconSize, actionIconSize: CGFloat
        public init(textEntry: Font, utilityIconSize: CGFloat, sendIcon: Font, stopIcon: Font, floatingSendIcon: Font, floatingSendIconSize: CGFloat, actionIconSize: CGFloat, actionTitle: Font) {
            self.textEntry = textEntry; self.utilityIconSize = utilityIconSize; self.sendIcon = sendIcon; self.stopIcon = stopIcon; self.floatingSendIcon = floatingSendIcon; self.floatingSendIconSize = floatingSendIconSize; self.actionIconSize = actionIconSize; self.actionTitle = actionTitle
        }
    }
    public struct StickerKeyboard {
        public var emojiGlyphSize, categoryIconSize: CGFloat
        public var emptyTitle, emptyBody: Font
        public init(emojiGlyphSize: CGFloat, categoryIconSize: CGFloat, emptyTitle: Font, emptyBody: Font) {
            self.emojiGlyphSize = emojiGlyphSize; self.categoryIconSize = categoryIconSize; self.emptyTitle = emptyTitle; self.emptyBody = emptyBody
        }
    }
    public struct StickerSearch {
        public var title, packTitle, metadata, searchField, actionLabel: Font
        public var iconSize: CGFloat
        public init(title: Font, packTitle: Font, metadata: Font, searchField: Font, actionLabel: Font, iconSize: CGFloat) {
            self.title = title; self.packTitle = packTitle; self.metadata = metadata; self.searchField = searchField; self.actionLabel = actionLabel; self.iconSize = iconSize
        }
    }
}
