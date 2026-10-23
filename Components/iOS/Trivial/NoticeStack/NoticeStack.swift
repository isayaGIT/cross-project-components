import SwiftUI

/// Compatibility model retained for existing call sites.
public struct NoticeStackItem: Identifiable {
    public let id: UUID
    public let title: String
    public let message: String
    public let systemImage: String?
    public let tint: Color
    public let actionTitle: String?
    fileprivate let action: (() -> Void)?

    public init(id: UUID = UUID(), title: String, message: String, systemImage: String? = nil, tint: Color = .accentColor, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.id = id; self.title = title; self.message = message; self.systemImage = systemImage; self.tint = tint; self.actionTitle = actionTitle; self.action = action
    }
}

/// Existing API backed by the original SwiftPieces Notice Stack animation and interaction.
public struct NoticeStack: View {
    @Binding private var notices: [NoticeStackItem]
    @State private var expanded = false
    private let maximumVisibleCards: Int

    public init(notices: Binding<[NoticeStackItem]>, maximumVisibleCards: Int = 3) {
        self._notices = notices
        self.maximumVisibleCards = min(5, max(1, maximumVisibleCards))
    }

    public var body: some View {
        SwiftPiecesNoticeStack(
            notices: Binding(
                get: { notices.map { item in
                    SwiftPiecesNoticeStack.Notice(
                        id: item.id.uuidString,
                        title: item.title,
                        message: item.message,
                        symbol: item.systemImage ?? "bell.fill",
                        tint: SwiftPiecesNoticeStack.Tint(item.tint)
                    )
                } },
                set: { updated in
                    let ids = Set(updated.map(\.id))
                    notices.removeAll { !ids.contains($0.id.uuidString) }
                }
            ),
            expanded: $expanded,
            onSelect: { selected in
                notices.first(where: { $0.id.uuidString == selected.id })?.action?()
            }
        )
    }
}
