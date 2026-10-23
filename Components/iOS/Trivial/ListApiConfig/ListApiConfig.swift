import SwiftUI

/// A lightweight vertical container for existing ListNode rows.
///
/// This view only arranges its content. Row appearance and behavior should be
/// implemented by the corresponding ListNode component, not duplicated here.
public struct ListApiConfig<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(
        spacing: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing.isFinite ? max(0, spacing) : 0
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: spacing) {
            content
        }
    }
}
