import SwiftUI

/// Reusable conversation sidebar composed from MessageListNode rows.
/// Conversation data and navigation remain owned by the calling feature.
public struct Sidebar<Conversation: Identifiable>: View where Conversation.ID: Hashable {
    private let title: String
    private let conversations: [Conversation]
    private let selectedID: Conversation.ID?
    private let rowContent: (Conversation, Bool) -> MessageListNode
    private let onSelect: (Conversation) -> Void
    private let onNewConversation: (() -> Void)?
    private let footer: AnyView?

    public init(
        title: String = "聊天",
        conversations: [Conversation],
        selectedID: Conversation.ID? = nil,
        onNewConversation: (() -> Void)? = nil,
        @ViewBuilder rowContent: @escaping (Conversation, Bool) -> MessageListNode,
        onSelect: @escaping (Conversation) -> Void,
        @ViewBuilder footer: () -> some View = { EmptyView() }
    ) {
        self.title = title
        self.conversations = conversations
        self.selectedID = selectedID
        self.onNewConversation = onNewConversation
        self.rowContent = rowContent
        self.onSelect = onSelect
        self.footer = AnyView(footer())
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.tint)
                Text(title).font(.title2.weight(.bold))
                Spacer()
                if let onNewConversation {
                    Button(action: onNewConversation) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .medium))
                            .frame(width: 38, height: 38)
                            .background(.quaternary, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("新建聊天")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                Text("搜索聊天").foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "line.3.horizontal.decrease").foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 20)

            Text("最近")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(conversations) { conversation in
                        let isSelected = selectedID == conversation.id
                        Button { onSelect(conversation) } label: {
                            rowContent(conversation, isSelected)
                                .background(isSelected ? Color.primary.opacity(0.065) : .clear,
                                            in: RoundedRectangle(cornerRadius: 12))
                                .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }

            Spacer(minLength: 0)
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemBackground).ignoresSafeArea())
    }
}
