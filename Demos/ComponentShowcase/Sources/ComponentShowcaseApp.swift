import SwiftUI
import Animated

@main
struct ComponentShowcaseApp: App {
    var body: some Scene {
        WindowGroup {
            ComponentShowcaseView()
                .tint(Color(red: 0.36, green: 0.38, blue: 0.96))
        }
    }
}

private enum ShowcasePage: String, CaseIterable, Identifiable {
    case gestures = "Gestures"
    case gestures2 = "Gestures2"
    case chat = "Chat"
    case notices = "Notices"
    case reaction = "Reaction"
    case apiKeySheet = "API Key Sheet"
    case reflectiveCard = "ReflectiveCard"
    case openShaders = "OpenShaders"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .gestures: "hand.tap.fill"
        case .gestures2: "hand.draw.fill"
        case .chat: "bubble.left.and.bubble.right.fill"
        case .notices: "bell.badge.fill"
        case .reaction: "heart.circle.fill"
        case .apiKeySheet: "key.horizontal.fill"
        case .reflectiveCard: "rectangle.on.rectangle.angled"
        case .openShaders: "sparkles"
        }
    }
}

private struct ShowcaseMessage: Identifiable, Equatable {
    let id: Int
    let text: String
    let isOutgoing: Bool
}

private struct ShowcaseConversation: Identifiable {
    let id: Int
    let name: String
    let message: String
    let symbol: String
    let tint: Color
}

private struct ComponentShowcaseView: View {
    @State private var selectedPage: ShowcasePage = .openShaders
    @Namespace private var pagePickerNamespace
    @State private var reactionLiked = false
    @State private var reactionSaved = false
    @State private var pressedCount = 0
    @State private var lastSwipeAction = "Swipe a row to reveal its actions"
    @State private var openSwipeRow: AnyHashable? = nil
    @State private var conversations = [
        ShowcaseConversation(id: 1, name: "Momo Chen", message: "The new build looks great!", symbol: "person.crop.circle.fill", tint: .purple),
        ShowcaseConversation(id: 2, name: "Design Team", message: "Let's check the spacing.", symbol: "person.3.fill", tint: .orange),
        ShowcaseConversation(id: 3, name: "Alex Morgan", message: "Sent you the photos 📷", symbol: "person.fill", tint: .blue)
    ]
    @State private var gestures2Conversations = [
        ShowcaseConversation(id: 11, name: "Momo Chen", message: "The new build looks great!", symbol: "person.crop.circle.fill", tint: .purple),
        ShowcaseConversation(id: 12, name: "Design Team", message: "Let's check the spacing.", symbol: "person.3.fill", tint: .orange),
        ShowcaseConversation(id: 13, name: "Alex Morgan", message: "Sent you the photos 📷", symbol: "person.fill", tint: .blue)
    ]
    @State private var openSwipeRow2: AnyHashable? = nil
    @State private var gestures2Status = "Swipe a MessageListNode row to test the extracted gesture modules"
    @State private var messages = [
        ShowcaseMessage(id: 1, text: "Hey! Did you try the new interactions?", isOutgoing: false),
        ShowcaseMessage(id: 2, text: "I'm testing them right now.", isOutgoing: true),
        ShowcaseMessage(id: 3, text: "The spring feels much nicer ✨", isOutgoing: false),
        ShowcaseMessage(id: 4, text: "Agreed. Try scrolling up, then add a message.", isOutgoing: true)
    ]
    @State private var notices: [SwiftPiecesNoticeStack.Notice] = [
        .init(id: "upload-complete", title: "Upload complete", message: "Your photos are ready to view.", symbol: "checkmark.circle.fill", tint: .sage, date: .now),
        .init(id: "new-message", title: "New message", message: "Momo sent you a voice message.", symbol: "bubble.left.fill", tint: .sky, date: .now.addingTimeInterval(-240)),
        .init(id: "reminder", title: "Reminder", message: "Your weekly review is waiting.", symbol: "calendar.badge.clock", tint: .butter, date: .now.addingTimeInterval(-3600))
    ]
    @State private var noticesExpanded = false
    @State private var nextMessageID = 5
    @State private var nextConversationID = 4
    @State private var nextNoticeID = 1

    private var voiceURL: URL {
        Bundle.main.url(forResource: "voice-sample", withExtension: "m4a") ?? URL(fileURLWithPath: "/dev/null")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    pagePicker
                    Group {
                        switch selectedPage {
                        case .gestures: gesturesPage
                        case .gestures2: gestures2Page
                        case .chat: chatPage
                        case .notices: noticesPage
                        case .reaction: reactionPage
                        case .apiKeySheet: apiKeySheetPage
                        case .reflectiveCard: ReflectiveCardPreview()
                        case .openShaders: OpenShadersDemoView()
                        }
                    }
                    .transition(.opacity)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 36)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(.tint)
                Text("COMPONENT LAB")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
            }
            Text("Motion, made tangible.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.8)
            Text("Try the gestures and feel each component respond.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var pagePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(Array(ShowcasePage.allCases.reversed())) { page in
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                            selectedPage = page
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: page.symbol)
                                .font(.system(size: 12, weight: .semibold))
                            Text(page.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 13)
                        .frame(height: 36)
                        .foregroundStyle(selectedPage == page ? Color.primary : Color.secondary)
                        .background {
                            if selectedPage == page {
                                Capsule(style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                    .matchedGeometryEffect(id: "showcase.page.selection", in: pagePickerNamespace)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedPage == page ? .isSelected : [])
                }
            }
            .padding(4)
        }
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
    }

    private var gesturesPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("Swipe Action Row", subtitle: "Swipe either direction to reveal actions.")
            VStack(spacing: 0) {
                ForEach(conversations) { conversation in
                    SwiftPiecesSwipeActionRow(
                        id: conversation.id,
                        trailing: [
                            .init("Delete", systemImage: "trash.fill", tint: Color(red: 1, green: 0, blue: 0), role: .destructive) {
                                withAnimation(.spring(duration: 0.3, bounce: 0.12)) {
                                    conversations.removeAll { $0.id == conversation.id }
                                }
                                openSwipeRow = nil
                                lastSwipeAction = "Deleted \(conversation.name)"
                            },
                            .init("Unread", systemImage: "envelope.badge.fill", tint: .init(red: 0.804, green: 0.722, blue: 1)) {
                                lastSwipeAction = "Marked \(conversation.name) as unread"
                            }
                        ],
                        open: $openSwipeRow
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: conversation.symbol)
                                .font(.system(size: 26))
                                .foregroundStyle(conversation.tint)
                                .frame(width: 42, height: 42)
                                .background(conversation.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conversation.name).font(.system(size: 14, weight: .semibold))
                                Text(conversation.message).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                    }
                    .frame(height: 66)
                    if conversation.id != conversations.last?.id {
                        Divider().padding(.leading, 66)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
            Text(lastSwipeAction)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            sectionHeading("Elastic Button", subtitle: "Press and release. Watch the soft squash snap back.")
            VStack(spacing: 14) {
                Button {
                    pressedCount += 1
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "heart.fill")
                        Text("Give it a press")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(LinearGradient(colors: [Color(red: 0.40, green: 0.42, blue: 0.98), Color(red: 0.54, green: 0.35, blue: 0.91)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.elastic)
                Text(pressedCount == 0 ? "Waiting for your touch" : "Pressed \(pressedCount) \(pressedCount == 1 ? "time" : "times")")
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var gestures2Page: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("MessageListNode · Extracted Gestures", subtitle: "Same gesture engine, wired through our MessageListNode component. Swipe left, release at different distances, and compare the spring landing.")

            VStack(spacing: 0) {
                ForEach(gestures2Conversations) { conversation in
                    MessageListNode(
                        title: conversation.name,
                        subtitle: conversation.message,
                        avatarPlaceholder: Image(systemName: conversation.symbol),
                        avatarSize: 42,
                        unreadCount: conversation.id == 11 ? 3 : nil,
                        titleFontSize: 14,
                        subtitleFontSize: 12,
                        padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12),
                        background: Background(color: .clear),
                        onDelete: {
                            withAnimation(.spring(duration: 0.3, bounce: 0.12)) {
                                gestures2Conversations.removeAll { $0.id == conversation.id }
                            }
                            openSwipeRow2 = nil
                            gestures2Status = "Deleted \(conversation.name)"
                        },
                        onMarkUnread: {
                            gestures2Status = "Marked \(conversation.name) as unread"
                        },
                        openSwipeRow: $openSwipeRow2
                    )
                    if conversation.id != gestures2Conversations.last?.id {
                        Divider().padding(.leading, 66)
                    }
                }
            }
            
            Text(gestures2Status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("This page uses Components/iOS/MessageListNode and the extracted ListNodeActions helpers. The row's visual treatment stays in the component layer; gesture physics and release behavior live in the dedicated gesture files.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .simultaneousGesture(TapGesture().onEnded {
            if openSwipeRow2 != nil {
                openSwipeRow2 = nil
            }
        })
    }

    private var chatPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("Waveform Scrub", subtitle: "Drag the waveform. The time preview follows your finger; release to seek.")
            VoiceMessageView(audioURL: voiceURL, displayMode: .waveform, duration: 9.5, tint: Color(red: 0.36, green: 0.38, blue: 0.96), width: nil)
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            HStack(alignment: .firstTextBaseline) {
                sectionHeading("Follow Scroll", subtitle: "Scroll up, then add a message.")
                Spacer()
                Button {
                    let id = nextMessageID
                    nextMessageID += 1
                    messages.append(ShowcaseMessage(id: id, text: ["Just arrived 👋", "Still follows the bottom?", "The reader keeps their place.", "One more message ✨"].randomElement()!, isOutgoing: true))
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.elastic)
            }

            FollowScroll(messages, style: FollowScrollStyle(spacing: 10)) { message in
                HStack {
                    if message.isOutgoing { Spacer(minLength: 38) }
                    Text(message.text)
                        .font(.system(size: 13))
                        .foregroundStyle(message.isOutgoing ? .white : .primary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(message.isOutgoing ? Color.accentColor : Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    if !message.isOutgoing { Spacer(minLength: 38) }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 290)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    @State private var isApiKeySheetPresented = true
    @State private var selectedProviderMessage = "选择一个服务商，查看点击反馈。"

    private var apiKeySheetPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading("SheetLlmApiKeyConfigSheet", subtitle: "正在检查的真实组件。点击下方按钮重新打开系统 Sheet，检查高度、圆角、背景和列表布局。")
            VStack(alignment: .leading, spacing: 10) {
                Label("Provider selection", systemImage: "rectangle.bottomhalf.inset.filled")
                    .font(.system(size: 14, weight: .semibold))
                Text(selectedProviderMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Button {
                    isApiKeySheetPresented = true
                } label: {
                    Label("打开 API Key 配置 Sheet", systemImage: "arrow.up.right.square")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .sheet(isPresented: $isApiKeySheetPresented) {
            SheetLlmApiKeyConfigSheet(
                providers: [
                    .init(id: "openai", title: "OpenAI", subtitle: "API Key 已配置", icon: Image(systemName: "sparkles"), status: .ready),
                    .init(id: "anthropic", title: "Anthropic", subtitle: "尚未添加 API Key", icon: Image(systemName: "brain.head.profile"), status: .unavailable),
                    .init(id: "google", title: "Google Gemini", subtitle: "连接验证中", icon: Image(systemName: "diamond.hex.fill"), status: .checking),
                    .init(id: "custom", title: "自定义 Provider", subtitle: "请求失败，请检查配置", icon: Image(systemName: "network"), status: .error)
                ],
                onSelectProvider: { provider in
                    selectedProviderMessage = "已点击：\(provider.title)（\(provider.id)）"
                    isApiKeySheetPresented = false
                }
            )
            .presentationDetents([.height(390), .medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
    }

    private var reactionPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("SwiftPieces · Reaction Toggle", subtitle: "Original SwiftPieces v2.2.0 source. Tap the controls to inspect the complete animation and interaction.")
            VStack(spacing: 26) {
                HStack(spacing: 24) {
                    VStack(spacing: 10) {
                        ReactionToggle(isOn: $reactionLiked, systemImage: "heart", count: 128, confirmation: "Liked")
                        Text("Contained · Like").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 10) {
                        ReactionToggle(isOn: $reactionSaved, systemImage: "bookmark", count: 36, confirmation: "Saved", style: .init(fill: .blue))
                        Text("Contained · Save").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Divider()
                HStack(spacing: 30) {
                    ReactionToggle(isOn: $reactionLiked, systemImage: "heart", size: 30, style: .init(isContained: false))
                    ReactionToggle(isOn: $reactionSaved, systemImage: "bookmark", size: 30, style: .init(fill: .blue, isContained: false))
                }
                Text("Bare symbols · no glass capsule").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var noticesPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("Notice Stack", subtitle: "Expand the stack, dismiss a card, or clear everything.")
            SwiftPiecesNoticeStack(notices: $notices, expanded: $noticesExpanded) { notice in
                lastSwipeAction = "Selected \(notice.title)"
            }
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            Button {
                nextNoticeID += 1
                let samples: [(String, String, String, Color)] = [
                    ("Sync complete", "Your latest changes are up to date.", "checkmark.icloud.fill", .green),
                    ("New reaction", "Someone loved your latest moment.", "heart.fill", .pink),
                    ("Weekly recap", "Your week is ready to review.", "chart.bar.fill", .orange),
                    ("New message", "You have a new conversation waiting.", "bubble.left.fill", .blue)
                ]
                let sample = samples[nextNoticeID % samples.count]
                withAnimation(.spring(duration: 0.35, bounce: 0.18)) {
                    let tint: SwiftPiecesNoticeStack.Tint = switch sample.3 {
                    case .green: .sage
                    case .pink, .purple: .lilac
                    case .orange: .butter
                    default: .sky
                    }
                    notices.insert(.init(id: UUID().uuidString, title: sample.0, message: sample.1, symbol: sample.2, tint: tint, date: .now), at: 0)
                }
            } label: {
                Label("Add a notice", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.elastic)

            if notices.isEmpty {
                ContentUnavailableView("All caught up", systemImage: "checkmark.circle", description: Text("Add a notice to try the stack again."))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .tracking(-0.35)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
