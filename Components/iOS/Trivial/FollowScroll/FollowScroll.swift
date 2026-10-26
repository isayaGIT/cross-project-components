import SwiftUI

/// Layout and behavior configuration for `FollowScroll`.
public struct FollowScrollStyle: Sendable {
    public var spacing: CGFloat
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat
    public var followThreshold: CGFloat
    public var showsJumpButton: Bool

    public init(
        spacing: CGFloat = 8,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 12,
        followThreshold: CGFloat = 48,
        showsJumpButton: Bool = true
    ) {
        self.spacing = max(0, spacing.isFinite ? spacing : 0)
        self.horizontalPadding = max(0, horizontalPadding.isFinite ? horizontalPadding : 0)
        self.verticalPadding = max(0, verticalPadding.isFinite ? verticalPadding : 0)
        self.followThreshold = max(1, followThreshold.isFinite ? followThreshold : 48)
        self.showsJumpButton = showsJumpButton
    }

    public static let standard = FollowScrollStyle()
}

/// A reusable scroll container. It knows item identity and scroll behavior, never the meaning or appearance of a row.
/// Callers provide row and empty-state views through builders.
public struct FollowScroll<Item: Identifiable, Row: View, Empty: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFollowing = true
    @State private var unreadCount = 0
    @State private var isLoadingOlder = false
    @State private var topIsArmed = true

    private let items: [Item]
    private let style: FollowScrollStyle
    private let alwaysFollow: (Item) -> Bool
    private let row: (Item) -> Row
    private let empty: Empty
    private let onReachTop: (@MainActor () async -> Void)?

    public init(
        _ items: [Item],
        style: FollowScrollStyle = .standard,
        alwaysFollow: @escaping (Item) -> Bool = { _ in false },
        @ViewBuilder row: @escaping (Item) -> Row,
        onReachTop: (@MainActor () async -> Void)? = nil,
        @ViewBuilder empty: () -> Empty
    ) {
        self.items = items
        self.style = style
        self.alwaysFollow = alwaysFollow
        self.row = row
        self.empty = empty()
        self.onReachTop = onReachTop
    }

    public var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: style.spacing) {
                        ForEach(items) { item in
                            row(item)
                                .id(item.id)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id(FollowScrollSentinel.bottom)
                    }
                    .padding(.horizontal, style.horizontalPadding)
                    .padding(.vertical, style.verticalPadding)
                    .background {
                        GeometryReader { content in
                            Color.clear.preference(
                                key: FollowScrollMetricsKey.self,
                                value: FollowScrollMetrics(
                                    minY: content.frame(in: .named("FollowScrollSpace")).minY,
                                    contentHeight: content.size.height,
                                    viewportHeight: viewport.size.height
                                )
                            )
                        }
                    }
                }
                .coordinateSpace(name: "FollowScrollSpace")
                .scrollIndicators(.hidden)
                .onPreferenceChange(FollowScrollMetricsKey.self) { metrics in
                    let distanceFromBottom = max(0, metrics.contentHeight - metrics.viewportHeight + metrics.minY)
                    let nearBottom = distanceFromBottom <= style.followThreshold
                    if nearBottom {
                        isFollowing = true
                        unreadCount = 0
                    } else {
                        isFollowing = false
                    }
                    let offsetFromTop = max(0, -metrics.minY)
                    if let onReachTop, !items.isEmpty {
                        if offsetFromTop < metrics.viewportHeight * 0.75, topIsArmed, !isLoadingOlder {
                            topIsArmed = false
                            Task { await loadOlder(onReachTop) }
                        } else if offsetFromTop > metrics.viewportHeight * 1.25 {
                            topIsArmed = true
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if style.showsJumpButton && !isFollowing && !items.isEmpty {
                        Button {
                            jumpToBottom(proxy, animated: true)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: unreadCount > 0 ? "arrow.down" : "arrow.down.to.line")
                                if unreadCount > 0 {
                                    Text("\(unreadCount) new")
                                } else {
                                    Text("Latest")
                                }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(.primary.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .overlay(alignment: .top) {
                    if isLoadingOlder {
                        ProgressView()
                            .padding(8)
                            .background(.regularMaterial, in: Capsule())
                            .padding(.top, 8)
                    }
                }
                .overlay {
                    if items.isEmpty {
                        empty.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .onChange(of: items.map(\.id)) { oldIDs, newIDs in
                    handleItemsChanged(from: oldIDs, to: newIDs, proxy: proxy)
                }
                .onAppear {
                    if !items.isEmpty {
                        jumpToBottom(proxy, animated: false)
                    }
                }
            }
        }
    }

    private func handleItemsChanged(from oldIDs: [Item.ID], to newIDs: [Item.ID], proxy: ScrollViewProxy) {
        if newIDs.first != oldIDs.first { topIsArmed = true }
        guard !newIDs.isEmpty else {
            unreadCount = 0
            return
        }
        guard let oldLastID = oldIDs.last else {
            isFollowing = true
            jumpToBottom(proxy, animated: false)
            return
        }
        guard let oldLastIndex = newIDs.firstIndex(where: { $0 == oldLastID }), oldLastIndex < newIDs.count - 1 else {
            // Prepending older items should not force a reader to the bottom.
            if newIDs.first != oldIDs.first { return }
            isFollowing = true
            unreadCount = 0
            jumpToBottom(proxy, animated: false)
            return
        }
        let appended = newIDs.suffix(from: newIDs.index(after: oldLastIndex))
        guard !appended.isEmpty else { return }
        let appendedItems = items.filter { appended.contains($0.id) }
        if isFollowing || appendedItems.contains(where: alwaysFollow) {
            isFollowing = true
            unreadCount = 0
            jumpToBottom(proxy, animated: !reduceMotion)
        } else {
            unreadCount += appended.count
        }
    }

    @MainActor
    private func loadOlder(_ action: @escaping @MainActor () async -> Void) async {
        guard !isLoadingOlder else { return }
        isLoadingOlder = true
        await action()
        isLoadingOlder = false
    }

    private func jumpToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        let action = { proxy.scrollTo(FollowScrollSentinel.bottom, anchor: .bottom) }
        if animated && !reduceMotion {
            withAnimation(.easeOut(duration: 0.22), action)
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, action)
        }
    }
}

public extension FollowScroll where Empty == EmptyView {
    init(
        _ items: [Item],
        style: FollowScrollStyle = .standard,
        alwaysFollow: @escaping (Item) -> Bool = { _ in false },
        @ViewBuilder row: @escaping (Item) -> Row,
        onReachTop: (@MainActor () async -> Void)? = nil
    ) {
        self.init(items, style: style, alwaysFollow: alwaysFollow, row: row, onReachTop: onReachTop, empty: { EmptyView() })
    }
}

private enum FollowScrollSentinel: Hashable {
    case bottom
}

private struct FollowScrollMetrics: Equatable {
    let minY: CGFloat
    let contentHeight: CGFloat
    let viewportHeight: CGFloat

    static let zero = FollowScrollMetrics(minY: 0, contentHeight: 0, viewportHeight: 0)
}

private struct FollowScrollMetricsKey: PreferenceKey {
    static var defaultValue = FollowScrollMetrics.zero
    static func reduce(value: inout FollowScrollMetrics, nextValue: () -> FollowScrollMetrics) {
        value = nextValue()
    }
}
