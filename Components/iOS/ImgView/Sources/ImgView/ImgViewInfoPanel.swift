import SwiftUI

/// A reusable image-information surface that can be dismissed with a downward swipe.
/// The drag recognizer is simultaneous so controls inside the supplied content remain interactive.
public struct ImgViewInfoPanel<Content: View>: View {
    private let onDismiss: () -> Void
    private let content: Content
    private let dismissThreshold: CGFloat

    @State private var dragOffset: CGFloat = 0

    public init(
        dismissThreshold: CGFloat = 64,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.dismissThreshold = dismissThreshold
        self.onDismiss = onDismiss
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .offset(y: max(0, dragOffset))
            .opacity(1 - min(max(dragOffset / 280, 0), 0.45))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onChanged { value in
                        guard value.translation.height > 0,
                              value.translation.height > abs(value.translation.width) else { return }
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let shouldDismiss = value.translation.height >= dismissThreshold &&
                            value.translation.height > abs(value.translation.width)
                        if shouldDismiss {
                            onDismiss()
                        }
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            dragOffset = 0
                        }
                    }
            )
            .accessibilityAction(named: Text("Dismiss image information")) {
                onDismiss()
            }
    }
}
