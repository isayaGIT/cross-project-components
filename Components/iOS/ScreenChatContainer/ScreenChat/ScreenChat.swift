import SwiftUI

/// A ready-to-use, front-end chat screen composed from the iOS component library.
/// The host app owns persistence, networking, and any real call/attachment actions.
public struct ScreenChat: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismissBottomSheet) private var dismissBottomSheet
    @State private var messages: [ScreenChatMessage]
    @State private var draft = ""
    @State private var isAppsPresented = false
    @State private var isStickerSearchPresented = false
    @State private var isInputActionPanelPresented = false
    @State private var isStickerPanelPresented = false
    @State private var selectedProfile: ProfileCard.Profile?
    @State private var selectedProfileIsCurrentUser = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let title: String
    private let subtitle: String
    private let avatar: Image?
    private let currentUserAvatar: Image?
    private let characterProfile: ProfileCard.Profile?
    private let currentUserProfile: ProfileCard.Profile?
    private let onProfileVoiceCall: ((Bool) -> Void)?
    private let onProfileListenTogether: ((Bool) -> Void)?
    private let onProfileMessage: ((Bool) -> Void)?
    private let onBack: (() -> Void)?
    private let onStopGenerating: (() -> Void)?
    private let isGenerating: Bool
    private let configuration: ScreenChatConfig?
    private let stickerKeyboardConfiguration: StickerKeyboard.Configuration
    private let inputContext: ScreenChatContainerInputContext?
    private let onOpenApp: ((ScreenChatApp) -> Void)?
    private let onInputAction: ((ScreenChatInputAction) -> Void)?

    public init(
        title: String = "Momo",
        subtitle: String = "在线",
        avatar: Image? = nil,
        currentUserAvatar: Image? = nil,
        characterProfile: ProfileCard.Profile? = nil,
        currentUserProfile: ProfileCard.Profile? = nil,
        onProfileVoiceCall: ((Bool) -> Void)? = nil,
        onProfileListenTogether: ((Bool) -> Void)? = nil,
        onProfileMessage: ((Bool) -> Void)? = nil,
        messages: [ScreenChatMessage] = ScreenChatMessage.preview,
        onBack: (() -> Void)? = nil,
        isGenerating: Bool = false,
        onStopGenerating: (() -> Void)? = nil,
        configuration: ScreenChatConfig? = nil,
        stickerKeyboardConfiguration: StickerKeyboard.Configuration = .standard,
        inputContext: ScreenChatContainerInputContext? = nil,
        onOpenApp: ((ScreenChatApp) -> Void)? = nil,
        onInputAction: ((ScreenChatInputAction) -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.avatar = avatar
        self.currentUserAvatar = currentUserAvatar
        self.characterProfile = characterProfile
        self.currentUserProfile = currentUserProfile
        self.onProfileVoiceCall = onProfileVoiceCall
        self.onProfileListenTogether = onProfileListenTogether
        self.onProfileMessage = onProfileMessage
        self.onBack = onBack
        self.isGenerating = isGenerating
        self.onStopGenerating = onStopGenerating
        self.configuration = configuration
        self.stickerKeyboardConfiguration = stickerKeyboardConfiguration
        self.inputContext = inputContext
        self.onOpenApp = onOpenApp
        self.onInputAction = onInputAction
        _messages = State(initialValue: messages)
    }

    private var config: ScreenChatConfig {
        configuration ?? .screenChat(colorScheme: colorScheme)
    }

    private var effectiveStickerKeyboardConfiguration: StickerKeyboard.Configuration {
        var value = stickerKeyboardConfiguration
        if let colors = config.themeColors {
            value.topBorderColor = colors.stickerKeyboard.topBorder
            value.categoryDividerColor = colors.stickerKeyboard.categoryDivider
            value.categoryBarBackground = colors.stickerKeyboard.categoryBarBackground
            value.categoryIconColor = colors.stickerKeyboard.categoryIcon
            value.selectedCategoryBackground = colors.stickerKeyboard.selectedCategoryBackground
            value.selectedCategoryBorderColor = colors.stickerKeyboard.selectedCategoryBorder
            value.panelSurface = AnyShapeStyle(colors.stickerKeyboard.panelBackground)
            value.loadingPlaceholderColor = colors.stickerKeyboard.loadingPlaceholder
            value.failureIconColor = colors.stickerKeyboard.failureIcon
            value.emptyIconColor = colors.stickerKeyboard.emptyIcon
            value.emptyPrimaryTextColor = colors.stickerKeyboard.emptyPrimary
            value.emptySecondaryTextColor = colors.stickerKeyboard.emptySecondary
            value.emojiBackground = colors.stickerKeyboard.emojiPanelSurface
            value.sendButtonBackground = colors.input.floatingSendBackground
            value.sendButtonFontColor = colors.input.floatingSendForeground
            value.sendButtonBorder = colors.input.floatingSendBorder
        }
        if let fonts = config.themeFonts {
            value.emojiFontSize = fonts.stickerKeyboard.emojiGlyphSize
            value.categoryIconFontSize = fonts.stickerKeyboard.categoryIconSize
            value.emptyIconFontSize = fonts.stickerKeyboard.categoryIconSize + 6
            value.emptyTitleFont = fonts.stickerKeyboard.emptyTitle
            value.emptyBodyFont = fonts.stickerKeyboard.emptyBody
            value.sendButtonFontSize = fonts.input.floatingSendIconSize
        }
        return value
    }

    // Stable layout defaults live here. ScreenChatConfig is reserved for theme variants.

    public var body: some View {
        VStack(spacing: 0) {
            HeaderChatScreen(
                title: title,
                configuration: config,
                onBack: onBack,
                onApps: presentAppsSheet
            )
            Divider().overlay(config.separatorColor.opacity(config.separatorOpacity))

            ChatContentContainer(
                messages,
                configuration: config,
                onTapContent: dismissInputPanels
            ) { message in
                messageRow(message)
                    .padding(.horizontal, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            InputContainer(
                text: $draft,
                isGenerating: isGenerating,
                configuration: config,
                stickerKeyboardConfiguration: effectiveStickerKeyboardConfiguration,
                inputContext: inputContext,
                isStickerPanelPresented: $isStickerPanelPresented,
                isToolsPanelPresented: $isInputActionPanelPresented,
                accessoryPanel: AnyView(
                    StickerKeyboard(
                        stickers: [],
                        packs: [],
                        assets: [],
                        configuration: effectiveStickerKeyboardConfiguration,
                        onSearchRequested: presentStickerSearch,
                        onEmojiSelect: { draft.append($0) },
                        onSelect: { _ in }
                    )
                ),
                toolsPanel: AnyView(
                    InputActionPanel(
                        actions: [
                        .init(id: "image", title: "图片", systemImage: "photo") {
                            onInputAction?(.image)
                        },
                        .init(id: "camera", title: "相机", systemImage: "camera") {
                            onInputAction?(.camera)
                        },
                        .init(id: "music", title: "音乐", systemImage: "music.note") {
                            onOpenApp?(.music)
                            onInputAction?(.music)
                        },
                        .init(id: "location", title: "位置", systemImage: "location") {
                            onInputAction?(.location)
                        }
                        ],
                        configuration: InputActionPanel.Configuration(
                            panelBackground: config.themeColors.map { AnyShapeStyle($0.input.actionPanelSurface) } ?? config.headerBackground,
                            tileBackground: config.themeColors.map { AnyShapeStyle($0.input.actionTileSurface) } ?? AnyShapeStyle(Color.secondary.opacity(0.08)),
                            foregroundColor: config.themeColors?.input.actionIcon ?? config.inputIconColor,
                            secondaryColor: config.themeColors?.input.actionSecondary ?? config.subtitleColor,
                            iconFont: config.themeFonts.map { .system(size: $0.input.actionIconSize) } ?? .system(size: 22),
                            titleFont: config.themeFonts?.input.actionTitle ?? .system(size: 12, weight: .medium)
                        )
                    )
                ),
                onSend: sendMessage,
                onStop: onStopGenerating
            )
        }
        .background { Rectangle().fill(config.background).ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            if case nil = inputContext {
                OverlayPresenter(
                    isPresented: $isAppsPresented,
                    configuration: appsSheetConfiguration
                ) {
                    appsSheetContent
                }
            }
        }
        .overlay {
            if case nil = inputContext {
                StickerSearchSheet(
                    isPresented: $isStickerSearchPresented,
                    configuration: stickerSearchConfiguration,
                    onSearch: { _ in }
                )
                .zIndex(2)
            }
        }
        .overlay { profileCardOverlay }
    }


    private var appsSheetConfiguration: BottomSheetPresentationConfiguration {
        BottomSheetPresentationConfiguration(
            height: .fraction(0.62),
            background: config.themeColors?.themePicker.sheetBackground
        )
    }

    private var appsSheetContent: some View {
        SheetApps(onSelect: { app in
            dismissBottomSheet()
            onOpenApp?(app)
        })
    }

    private var stickerSearchConfiguration: StickerSearchSheet.Configuration {
        StickerSearchSheet.Configuration(
            titleColor: config.themeColors?.stickerSearch.title ?? config.titleColor,
            secondaryTextColor: config.themeColors?.stickerSearch.secondary ?? config.subtitleColor,
            inputBackground: config.themeColors?.stickerSearch.searchBackground ?? Color.primary.opacity(0.06),
            surfaceBackground: config.themeColors?.stickerSearch.surface ?? Color(uiColor: .systemBackground),
            actionIconColor: config.themeColors?.stickerSearch.actionIcon ?? config.inputIconColor,
            selectionIconColor: config.themeColors?.stickerSearch.selectionIcon ?? config.inputIconColor,
            packTileBackground: config.themeColors?.stickerSearch.packTileSurface ?? Color.primary.opacity(0.06),
            packStateBackground: config.themeColors?.stickerSearch.packStateSurface ?? Color.primary.opacity(0.045),
            titleFont: config.themeFonts?.stickerSearch.title ?? .headline,
            packTitleFont: config.themeFonts?.stickerSearch.packTitle ?? .system(size: 16, weight: .semibold),
            metadataFont: config.themeFonts?.stickerSearch.metadata ?? .system(size: 13),
            actionLabelFont: config.themeFonts?.stickerSearch.actionLabel ?? .system(size: 13, weight: .medium),
            iconSize: config.themeFonts?.stickerSearch.iconSize ?? 17
        )
    }

    private var stickerSearchSheetConfiguration: BottomSheetPresentationConfiguration {
        BottomSheetPresentationConfiguration(
            height: .fraction(0.90),
            background: stickerSearchConfiguration.surfaceBackground,
            showsGrabber: true,
            dismissOnBackdropTap: true,
            dismissOnDrag: true
        )
    }

    private func presentStickerSearch() {
        guard let inputContext else {
            isStickerSearchPresented = true
            return
        }

        let content = StickerSearchSheet(
            isPresented: .constant(true),
            configuration: stickerSearchConfiguration,
            hostedContentOnly: true,
            onSearch: { _ in }
        )
        inputContext.presentBottomSheet(AnyView(content), stickerSearchSheetConfiguration)
    }

    private func presentAppsSheet() {
        guard let inputContext else {
            isAppsPresented = true
            return
        }
        inputContext.presentBottomSheet(AnyView(appsSheetContent), appsSheetConfiguration)
    }

    private func messageRow(_ message: ScreenChatMessage) -> AnyView {
        AnyView(
            MessageChunk(
                direction: message.isOutgoing ? .outgoing : .incoming,
                avatar: message.isOutgoing ? (currentUserAvatar ?? currentUserProfile?.profileImage) : (avatar ?? characterProfile?.profileImage),
                timestamp: message.timestamp,
                configuration: config.messageConfiguration,
                onAvatarTap: {
                    let isOutgoing = message.isOutgoing
                    let fallbackProfile = isOutgoing
                        ? ProfileCard.Profile(name: "我", signature: "", profileImage: currentUserAvatar ?? currentUserProfile?.profileImage)
                        : ProfileCard.Profile(name: title, signature: subtitle, profileImage: avatar ?? characterProfile?.profileImage)
                    withAnimation(SwiftPiecesProfileCardMotion.reveal(reduceMotion: reduceMotion)) {
                        selectedProfileIsCurrentUser = isOutgoing
                        selectedProfile = isOutgoing ? (currentUserProfile ?? fallbackProfile) : (characterProfile ?? fallbackProfile)
                    }
                },
                content: {
                    AnyView(
                        Text(message.text)
                            .textSelection(.enabled)
                    )
                }
            )
        )
    }

    @ViewBuilder
    private var profileCardOverlay: some View {
        if let profile = selectedProfile {
            ZStack {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissProfileCard() }
                    .transition(.opacity)
                    .accessibilityLabel("关闭个人资料")

                ProfileCard(
                    profile: profile,
                    style: .default,
                    onVoiceCall: { onProfileVoiceCall?(selectedProfileIsCurrentUser) },
                    onListenTogether: { onProfileListenTogether?(selectedProfileIsCurrentUser) },
                    onMessage: { onProfileMessage?(selectedProfileIsCurrentUser) },
                    thumbnailRenderer: { moment, size in
                        AnyView(ImgThumbnail(image: moment.thumbnail, size: CGSize(width: size, height: size), shape: .square))
                    }
                )
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 24)
                    .transition(
                        .asymmetric(
                            insertion: SwiftPiecesProfileCardMotion.insertion(reduceMotion: reduceMotion),
                            removal: SwiftPiecesProfileCardMotion.removal(reduceMotion: reduceMotion)
                        )
                    )
                    .zIndex(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(100)
        }
    }

    private func dismissInputPanels() {
        isInputActionPanelPresented = false
        isStickerPanelPresented = false
        if let inputContext {
            inputContext.isStickerPanelPresented.wrappedValue = false
        }
        dismissKeyboard()
    }

    private func dismissKeyboard() {
        isStickerPanelPresented = false
        if let inputContext {
            inputContext.dismissKeyboard()
        } else {
            #if canImport(UIKit)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
        }
    }

    private func dismissProfileCard() {
        withAnimation(SwiftPiecesProfileCardMotion.dismiss(reduceMotion: reduceMotion)) {
            selectedProfile = nil
        }
    }

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        messages.append(
            ScreenChatMessage(
                text: text,
                isOutgoing: true,
                timestamp: formatter.string(from: Date())
            )
        )
        draft = ""
    }
}

/// Minimal display model for ScreenChat. Replace it with an adapter to the host app's message model.
public struct ScreenChatMessage: Identifiable, Equatable {
    public let id: UUID
    public var text: String
    public var isOutgoing: Bool
    public var timestamp: String?

    public init(
        id: UUID = UUID(),
        text: String,
        isOutgoing: Bool,
        timestamp: String? = nil
    ) {
        self.id = id
        self.text = text
        self.isOutgoing = isOutgoing
        self.timestamp = timestamp
    }

    public static let preview: [ScreenChatMessage] = [
        .init(text: "早上好！☀️", isOutgoing: false, timestamp: "09:38"),
        .init(text: "早！今天的天气看起来不错。", isOutgoing: true, timestamp: "09:39"),
        .init(text: "下午要不要一起去喝咖啡？我发现了一家新店。", isOutgoing: false, timestamp: "09:40"),
        .init(text: "好呀！发我地址，我忙完就过去。", isOutgoing: true, timestamp: "09:41"),
        .init(text: "这家店的环境很好，感觉你会喜欢 ☕️", isOutgoing: false, timestamp: "09:42")
    ]
}

/// Actions exposed by the chat composer. The host app supplies concrete attachment,
/// camera, and location workflows; the reusable component does not own app permissions
/// or attachment upload policy.
public enum ScreenChatInputAction: String, CaseIterable, Identifiable {
    case image
    case camera
    case music
    case location

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .image: return "图片"
        case .camera: return "相机"
        case .music: return "音乐"
        case .location: return "位置"
        }
    }
}
