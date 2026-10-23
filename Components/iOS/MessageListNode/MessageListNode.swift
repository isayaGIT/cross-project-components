import SwiftUI
#if canImport(BackgroundData)
import BackgroundData
#endif

/// A conversation-list row showing a person's avatar, name, and latest message.
///
/// The host owns message data and state. This view only renders the row and forwards
/// configured swipe actions to the host.
public struct MessageListNode: View {
    private let title: String
    private let subtitle: String
    private let avatarImage: Image?
    private let avatarPlaceholder: Image?
    private let avatarSize: CGFloat
    private let avatarShape: Avatar.Shape
    private let unreadCount: Int?
    private let onUnreadBadgeDismiss: (() -> Void)?
    private let titleFont: Font?
    private let subtitleFont: Font?
    private let titleFontSize: CGFloat
    private let subtitleFontSize: CGFloat
    private let titleTextColor: Color
    private let subtitleTextColor: Color
    private let maxTitleCharacters: Int?
    private let maxSubtitleCharacters: Int?
    private let spacing: CGFloat
    private let padding: EdgeInsets
    private let background: Background
    private let topBorder: AnyView?
    private let bottomBorder: AnyView?
    private let onDelete: (() -> Void)?
    private let onMarkUnread: (() -> Void)?
    private let openSwipeRow: Binding<AnyHashable?>?

    /// Creates a conversation-list row. Custom `Font` values take precedence over
    /// their corresponding size values; leave them nil to use configurable system font sizes.
    public init(
        title: String,
        subtitle: String,
        avatarImage: Image? = nil,
        avatarPlaceholder: Image? = nil,
        avatarSize: CGFloat = 48,
        avatarShape: Avatar.Shape = .roundedRectangle(cornerRadius: 6),
        unreadCount: Int? = nil,
        onUnreadBadgeDismiss: (() -> Void)? = nil,
        titleFont: Font? = nil,
        subtitleFont: Font? = nil,
        titleFontSize: CGFloat = 16,
        subtitleFontSize: CGFloat = 14,
        titleTextColor: Color = .primary,
        subtitleTextColor: Color = .secondary,
        maxTitleCharacters: Int? = 40,
        maxSubtitleCharacters: Int? = 100,
        spacing: CGFloat = 4,
        padding: EdgeInsets = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16),
        background: Background = Background(color: .clear),
        topBorder: AnyView? = nil,
        bottomBorder: AnyView? = nil,
        onDelete: (() -> Void)? = nil,
        onMarkUnread: (() -> Void)? = nil,
        openSwipeRow: Binding<AnyHashable?>? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.avatarImage = avatarImage
        self.avatarPlaceholder = avatarPlaceholder
        self.avatarSize = avatarSize.isFinite ? max(0, avatarSize) : 48
        self.avatarShape = avatarShape
        self.unreadCount = unreadCount.map { max(0, $0) }
        self.onUnreadBadgeDismiss = onUnreadBadgeDismiss
        self.titleFont = titleFont
        self.subtitleFont = subtitleFont
        self.titleFontSize = titleFontSize.isFinite ? max(1, titleFontSize) : 16
        self.subtitleFontSize = subtitleFontSize.isFinite ? max(1, subtitleFontSize) : 14
        self.titleTextColor = titleTextColor
        self.subtitleTextColor = subtitleTextColor
        self.maxTitleCharacters = maxTitleCharacters
        self.maxSubtitleCharacters = maxSubtitleCharacters
        self.spacing = spacing.isFinite ? max(0, spacing) : 4
        self.padding = padding
        self.background = background
        self.topBorder = topBorder
        self.bottomBorder = bottomBorder
        self.onDelete = onDelete
        self.onMarkUnread = onMarkUnread
        self.openSwipeRow = openSwipeRow
    }

    public var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Avatar(
                    image: avatarImage,
                    width: avatarSize,
                    height: avatarSize,
                    shape: avatarShape,
                    scaling: .fill,
                    placeholder: avatarPlaceholder
                )
                .accessibilityHidden(true)

                if let unreadCount, unreadCount > 0 {
                    UnreadBadge(count: unreadCount, diameter: 20, onDismiss: {
                        onUnreadBadgeDismiss?()
                    })
                    .offset(x: 5, y: -5)
                }
            }

            VStack(alignment: .leading, spacing: spacing) {
                Text(limitedText(title, maximum: maxTitleCharacters))
                    .font(titleFont ?? .system(size: titleFontSize, weight: .semibold))
                    .foregroundStyle(titleTextColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(limitedText(subtitle, maximum: maxSubtitleCharacters))
                    .font(subtitleFont ?? .system(size: subtitleFontSize))
                    .foregroundStyle(subtitleTextColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { background }
        .overlay(alignment: .top) {
            if let topBorder { topBorder }
        }
        .overlay(alignment: .bottom) {
            if let bottomBorder { bottomBorder }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .modifier(MessageListNodeSwipeActions(onDelete: onDelete, onMarkUnread: onMarkUnread, openSwipeRow: openSwipeRow))
    }

    private func limitedText(_ text: String, maximum: Int?) -> String {
        guard let maximum else { return text }
        guard maximum > 0, text.count > maximum else {
            return maximum <= 0 ? "" : text
        }
        if maximum == 1 { return "…" }
        return String(text.prefix(maximum - 1)) + "…"
    }
}

private struct MessageListNodeSwipeActions: ViewModifier {
    let onDelete: (() -> Void)?
    let onMarkUnread: (() -> Void)?
    let openSwipeRow: Binding<AnyHashable?>?

    func body(content: Content) -> some View {
        let actions = [
            onDelete.map { callback in
                SwipeRowAction("删除", systemImage: "trash", tint: .red, role: .destructive, action: callback)
            },
            onMarkUnread.map { callback in
                SwipeRowAction("标为未读", systemImage: "envelope.badge", tint: .blue, action: callback)
            }
        ].compactMap { $0 }

        if actions.isEmpty {
            content
        } else {
            SwipeActionRow(actions: actions, allowsFullSwipe: false, open: openSwipeRow) {
                content
            }
        }
    }
}
