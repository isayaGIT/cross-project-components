import SwiftUI

/// A ready-to-use, front-end chat screen composed from the iOS component library.
/// The host app owns persistence, networking, and any real call/attachment actions.
public struct ScreenChat: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var messages: [ScreenChatMessage]
    @State private var draft = ""
    @State private var selectedTheme: ScreenChatTheme = .system
    @State private var isThemePickerPresented = false
    @State private var isChatSettingsPresented = false
    @State private var selectedProfile: ProfileCard.Profile?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let title: String
    private let subtitle: String
    private let avatar: Image?
    private let currentUserAvatar: Image?
    private let onBack: (() -> Void)?
    private let onToggleSidebar: (() -> Void)?
    private let onStopGenerating: (() -> Void)?
    private let isGenerating: Bool
    private let configuration: ScreenChatConfig?

    public init(
        title: String = "Momo",
        subtitle: String = "在线",
        avatar: Image? = nil,
        currentUserAvatar: Image? = nil,
        messages: [ScreenChatMessage] = ScreenChatMessage.preview,
        onBack: (() -> Void)? = nil,
        onToggleSidebar: (() -> Void)? = nil,
        isGenerating: Bool = false,
        onStopGenerating: (() -> Void)? = nil,
        configuration: ScreenChatConfig? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.avatar = avatar
        self.currentUserAvatar = currentUserAvatar
        self.onBack = onBack
        self.onToggleSidebar = onToggleSidebar
        self.isGenerating = isGenerating
        self.onStopGenerating = onStopGenerating
        self.configuration = configuration
        _messages = State(initialValue: messages)
    }

    private var config: ScreenChatConfig {
        if selectedTheme == .system {
            return configuration ?? .screenChat(colorScheme: colorScheme)
        }
        return ScreenChatThemes.configuration(for: selectedTheme, colorScheme: colorScheme)
    }

    // Stable layout defaults live here. ScreenChatConfig is reserved for theme variants.

    public var body: some View {
        VStack(spacing: 0) {
            HeaderChatScreen(
                title: title,
                configuration: config,
                onBack: onToggleSidebar ?? onBack,
                onThemePicker: { isThemePickerPresented = true },
                onChatSettings: { isChatSettingsPresented = true }
            )
            Divider().overlay(config.separatorColor.opacity(config.separatorOpacity))

            // Viewport 1: messages own all remaining space between the header and composer.
            // The scroll view is explicitly constrained and clipped to this region.
            messagesViewport
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            // Viewport 2: composer participates in the parent VStack's layout and
            // reserves its own height; it never overlays the message viewport.
            inputViewport
        }
        .background { Rectangle().fill(config.background).ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isThemePickerPresented) {
            themePicker
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .overlay {
            SheetCustom(
                isPresented: $isChatSettingsPresented,
                configuration: SheetCustomConfiguration(height: .fraction(0.38))
            ) {
                SheetSettingsChatSettings()
            }
        }
        .overlay { profileCardOverlay }
    }

    private var messagesViewport: some View {
        VStack(spacing: 0) {
            Text("今天")
                .font(config.dayLabelFont)
                .foregroundStyle(config.dayLabelColor)
                .padding(.top, 12)
                .padding(.bottom, 6)

            FollowScrollView(messages, id: \.id, spacing: 7, verticalPadding: 0) { message in
                messageRow(message)
                    .padding(.horizontal, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }

    private var inputViewport: some View {
        InputBar(
            text: $draft,
            isGenerating: isGenerating,
            onSend: sendMessage,
            onStop: onStopGenerating
        )
        .foregroundStyle(config.inputTextColor)
        .tint(config.inputIconColor)
        .padding(.horizontal, 12)
        .padding(.bottom, 7)
        .padding(.top, 8)
    }

    private var themePicker: some View {
        NavigationStack {
            List {
                ForEach(ScreenChatTheme.allCases) { theme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTheme = theme
                        }
                        isThemePickerPresented = false
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(ScreenChatThemes.previewColor(for: theme))
                                .frame(width: 42, height: 42)
                                .overlay {
                                    Image(systemName: theme.symbol)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(theme.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(theme.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedTheme == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.system(size: 19))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("聊天主题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { isThemePickerPresented = false }
                }
            }
        }
    }

    private func messageRow(_ message: ScreenChatMessage) -> AnyView {
        AnyView(
            MessageChunk(
                direction: message.isOutgoing ? .outgoing : .incoming,
                avatar: message.isOutgoing ? currentUserAvatar : avatar,
                timestamp: message.timestamp,
                configuration: config.messageConfiguration,
                onAvatarTap: {
                    let isOutgoing = message.isOutgoing
                    let profile = ProfileCard.Profile(
                        name: isOutgoing ? "我" : title,
                        signature: isOutgoing ? "我的个人资料" : subtitle,
                        profileImage: message.isOutgoing ? currentUserAvatar : avatar
                    )
                    withAnimation(SwiftPiecesProfileCardMotion.reveal(reduceMotion: reduceMotion)) {
                        selectedProfile = profile
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
                Color.black.opacity(0.34)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissProfileCard() }
                    .transition(.opacity)
                    .accessibilityLabel("关闭个人资料")

                ProfileCard(profile: profile, style: .default)
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
