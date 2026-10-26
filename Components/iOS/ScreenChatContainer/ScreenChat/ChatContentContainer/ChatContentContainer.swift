import SwiftUI

/// Organizes the content between the chat header and input area.
/// Message rendering is supplied by the caller; scrolling behavior is delegated to `FollowScroll`.
public struct ChatContentContainer<Item: Identifiable, Row: View, Empty: View>: View {
    private let items: [Item]
    private let configuration: ScreenChatConfig
    private let style: FollowScrollStyle
    private let onTapContent: (() -> Void)?
    private let row: (Item) -> Row
    private let empty: Empty

    public init(
        _ items: [Item],
        configuration: ScreenChatConfig,
        style: FollowScrollStyle = FollowScrollStyle(spacing: 7, horizontalPadding: 16, verticalPadding: 0),
        onTapContent: (() -> Void)? = nil,
        @ViewBuilder row: @escaping (Item) -> Row,
        @ViewBuilder empty: () -> Empty
    ) {
        self.items = items
        self.configuration = configuration
        self.style = style
        self.onTapContent = onTapContent
        self.row = row
        self.empty = empty()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Text("今天")
                .font(configuration.dayLabelFont)
                .foregroundStyle(configuration.dayLabelColor)
                .padding(.top, 12)
                .padding(.bottom, 6)

            FollowScroll(items, style: style, row: row) {
                empty
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .scrollDismissesKeyboard(.interactively)
        }
        // Attach to the whole chat-content region, not only the scroll view, so
        // tapping the day label also dismisses an open sticker keyboard.
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { onTapContent?() })
    }
}

public extension ChatContentContainer where Empty == EmptyView {
    init(
        _ items: [Item],
        configuration: ScreenChatConfig,
        style: FollowScrollStyle = FollowScrollStyle(spacing: 7, horizontalPadding: 16, verticalPadding: 0),
        onTapContent: (() -> Void)? = nil,
        @ViewBuilder row: @escaping (Item) -> Row
    ) {
        self.init(items, configuration: configuration, style: style, onTapContent: onTapContent, row: row, empty: { EmptyView() })
    }
}
