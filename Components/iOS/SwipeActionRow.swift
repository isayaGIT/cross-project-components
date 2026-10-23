import SwiftUI

/// Compatibility action type retained for existing component call sites.
public enum SwipeActionEdge: Sendable { case leading, trailing }

public struct SwipeRowAction: Identifiable {
    public let id: UUID
    public let title: String
    public let systemImage: String
    public let tint: Color
    public let role: ButtonRole?
    public let edge: SwipeActionEdge
    fileprivate let handler: () -> Void

    public init(_ title: String, systemImage: String, tint: Color, role: ButtonRole? = nil, edge: SwipeActionEdge = .trailing, id: UUID = UUID(), action: @escaping () -> Void) {
        self.id = id; self.title = title; self.systemImage = systemImage; self.tint = tint; self.role = role; self.edge = edge; self.handler = action
    }
}

/// Existing API backed by the original SwiftPieces swipe-row implementation.
public struct SwipeActionRow<Content: View>: View {
    private let actions: [SwipeRowAction]
    private let actionWidth: CGFloat
    private let allowsFullSwipe: Bool
    private let open: Binding<AnyHashable?>?
    private let content: Content

    public init(actions: [SwipeRowAction], allowsFullSwipe: Bool = false, actionWidth: CGFloat = 76, open: Binding<AnyHashable?>? = nil, @ViewBuilder content: () -> Content) {
        self.actions = actions
        self.actionWidth = actionWidth.isFinite ? min(120, max(56, actionWidth)) : 76
        self.allowsFullSwipe = allowsFullSwipe
        self.open = open
        self.content = content()
    }

    public var body: some View {
        SwiftPiecesSwipeActionRow(
            leading: actions.filter { $0.edge == .leading }.map { .init($0.title, systemImage: $0.systemImage, tint: $0.tint, role: $0.role, handler: $0.handler) },
            trailing: actions.filter { $0.edge == .trailing }.map { .init($0.title, systemImage: $0.systemImage, tint: $0.tint, role: $0.role, handler: $0.handler) },
            open: open,
            style: { var style = SwipeActionRowStyle.standard; style.tileWidth = actionWidth; return style }(),
            allowsFullSwipe: allowsFullSwipe,
            content: { content }
        )
    }
}
