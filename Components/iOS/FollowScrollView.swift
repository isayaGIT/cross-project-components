import SwiftUI

private struct FollowScrollElement<Element, Key: Hashable>: Identifiable {
    let value: Element
    let id: Key
}

/// Compatibility wrapper for the original SwiftPieces Follow Scroll implementation.
public struct FollowScrollView<Data: RandomAccessCollection, ItemID: Hashable, RowContent: View>: View {
    private let items: Data
    private let id: KeyPath<Data.Element, ItemID>
    private let showsIndicators: Bool
    private let spacing: CGFloat
    private let verticalPadding: CGFloat
    private let onNewItems: (() -> Void)?
    private let rowContent: (Data.Element) -> RowContent
    @State private var isFollowing = true
    @State private var previousCount: Int

    public init(_ items: Data, id: KeyPath<Data.Element, ItemID>, showsIndicators: Bool = false, spacing: CGFloat = 0, verticalPadding: CGFloat = 12, onNewItems: (() -> Void)? = nil, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) {
        self.items = items
        self.id = id
        self.showsIndicators = showsIndicators
        self.spacing = spacing.isFinite ? max(0, spacing) : 0
        self.verticalPadding = verticalPadding.isFinite ? max(0, verticalPadding) : 0
        self.onNewItems = onNewItems
        self.rowContent = rowContent
        _previousCount = State(initialValue: items.count)
    }

    public var body: some View {
        let adapted = items.map { FollowScrollElement(value: $0, id: $0[keyPath: id]) }
        FollowScroll(adapted, isFollowing: $isFollowing, style: followStyle) { item in
            rowContent(item.value)
        }
        .scrollIndicators(showsIndicators ? .visible : .hidden)
        .onChange(of: items.count) { _, count in
            let added = count > previousCount
            previousCount = count
            if added && !isFollowing { onNewItems?() }
        }
    }

    private var followStyle: FollowScrollStyle {
        var style = FollowScrollStyle.standard
        style.spacing = spacing
        style.verticalPadding = verticalPadding
        return style
    }
}
