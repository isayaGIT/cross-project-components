import SwiftUI

/// Reusable conversation sidebar composed from MessageListNode rows.
/// Conversation data and navigation remain owned by the calling feature.
public struct Sidebar<Conversation: Identifiable>: View where Conversation.ID: Hashable {
    @State private var searchText = ""

    private let title: String
    private let conversations: [Conversation]
    private let searchableText: ((Conversation) -> String)?
    private let selectedID: Conversation.ID?
    private let rowContent: (Conversation, Bool) -> MessageListNode
    private let onSelect: (Conversation) -> Void
    private let onNewConversation: (() -> Void)?
    private let footer: AnyView?
    private let headerLeading: AnyView?
    private let headerTrailing: AnyView?
    private let appearance: SidebarAppearance

    public init(
        title: String = "聊天",
        conversations: [Conversation],
        selectedID: Conversation.ID? = nil,
        searchableText: ((Conversation) -> String)? = nil,
        appearance: SidebarAppearance = .default,
        onNewConversation: (() -> Void)? = nil,
        headerLeading: AnyView? = nil,
        headerTrailing: AnyView? = nil,
        @ViewBuilder rowContent: @escaping (Conversation, Bool) -> MessageListNode,
        onSelect: @escaping (Conversation) -> Void,
        @ViewBuilder footer: () -> some View = { EmptyView() }
    ) {
        self.title = title
        self.conversations = conversations
        self.searchableText = searchableText
        self.selectedID = selectedID
        self.appearance = appearance
        self.onNewConversation = onNewConversation
        self.headerLeading = headerLeading
        self.headerTrailing = headerTrailing
        self.rowContent = rowContent
        self.onSelect = onSelect
        self.footer = AnyView(footer())
    }

    private var filteredConversations: [Conversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return conversations }
        return conversations.filter { conversation in
            let searchable = searchableText?(conversation) ?? String(describing: conversation)
            return searchable.localizedCaseInsensitiveContains(query)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let headerLeading {
                    headerLeading
                } else {
                    SidebarMosaicMark(color: appearance.header.icon)
                        .frame(width: 34, height: 34)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(appearance.typography.headerTitle)
                            .tracking(-0.45)
                            .foregroundStyle(appearance.header.title)
                        Text("YOUR CONVERSATIONS")
                            .font(appearance.typography.sectionHeading)
                            .tracking(1.5)
                            .foregroundStyle(appearance.sectionHeader.text)
                    }
                }
                Spacer(minLength: 8)
                if let headerTrailing {
                    headerTrailing
                } else if let onNewConversation {
                    Button(action: onNewConversation) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: appearance.typography.newConversationIconSize, weight: .medium))
                            .frame(width: 36, height: 36)
                            .foregroundStyle(appearance.header.newConversationForeground)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("新建聊天")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 18)

            SearchBar(
                text: $searchText,
                placeholder: "搜索聊天",
                capsuleStyle: appearance.usesGlass
                    ? SearchBarCapsuleStyle(texture: .material(.ultraThin), border: .solid(color: .white.opacity(0.72), lineWidth: 1))
                    : .init()
            )
            .background {
                if appearance.usesGlass {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.72), lineWidth: 1))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 20)

            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(filteredConversations) { conversation in
                        let isSelected = selectedID == conversation.id
                        Button { onSelect(conversation) } label: {
                            rowContent(conversation, isSelected)
                                .foregroundStyle(isSelected ? appearance.conversationRow.selectedForeground : appearance.conversationRow.primaryText)
                                .background {
                                    if isSelected && appearance.usesGlass {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(.regularMaterial)
                                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
                                    } else {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(isSelected ? appearance.conversationRow.selectedBackground : appearance.conversationRow.background)
                                    }
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)

                if filteredConversations.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .padding(.top, 24)
                }
            }

            Spacer(minLength: 0)
            Divider().overlay(appearance.separator)
            footer
                .foregroundStyle(appearance.footer.foreground)
                .background {
                    if appearance.usesGlass {
                        Rectangle().fill(.ultraThinMaterial)
                            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.65)).frame(height: 1) }
                    } else {
                        appearance.footer.background
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(appearance.background.ignoresSafeArea())
    }
}

/// A tiny animated mosaic signature for the sidebar. It uses native SwiftUI drawing only,
/// so it stays lightweight and doesn't add a package or Metal-shader dependency.
private struct SidebarMosaicMark: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let cells: [(x: Int, y: Int, size: CGFloat, opacity: Double)] = [
        (0, 0, 8, 0.55), (1, 0, 5, 0.9), (2, 0, 7, 0.7),
        (0, 1, 5, 0.85), (1, 1, 9, 1), (2, 1, 5, 0.6),
        (0, 2, 7, 0.7), (1, 2, 5, 0.5), (2, 2, 8, 0.95)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for (index, cell) in cells.enumerated() {
                    let wave = (sin(phase * 1.25 + Double(index) * 0.83) + 1) / 2
                    let side = cell.size * (0.78 + wave * 0.22)
                    let rect = CGRect(x: CGFloat(cell.x) * 10 + (10 - side) / 2,
                                      y: CGFloat(cell.y) * 10 + (10 - side) / 2,
                                      width: side, height: side)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color.opacity(cell.opacity * (0.72 + wave * 0.28))))
                }
            }
        }
    }
}
