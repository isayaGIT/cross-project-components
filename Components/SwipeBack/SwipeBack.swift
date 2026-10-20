import SwiftUI

/// A reusable leading-edge swipe-to-dismiss container that reveals a background view.
/// Use it for custom navigation flows; standard NavigationStack back navigation is preferred when applicable.
public struct SwipeBack<Background: View, Content: View>: View {
    private let onDismiss: () -> Void
    private let background: () -> Background
    private let content: () -> Content
    private let edgeWidth: CGFloat
    private let dismissFraction: CGFloat
    private let minimumDistance: CGFloat
    private let animated: Bool
    private let onHaptic: (() -> Void)?

    @State private var offset: CGFloat = 0
    @State private var directionIsHorizontal: Bool?

    public init(
        edgeWidth: CGFloat = 28,
        dismissFraction: CGFloat = 0.42,
        minimumDistance: CGFloat = 8,
        animated: Bool = true,
        onHaptic: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void,
        @ViewBuilder background: @escaping () -> Background,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.edgeWidth = max(1, edgeWidth)
        self.dismissFraction = min(max(dismissFraction, 0.1), 0.9)
        self.minimumDistance = max(0, minimumDistance)
        self.animated = animated
        self.onHaptic = onHaptic
        self.onDismiss = onDismiss
        self.background = background
        self.content = content
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                background()
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(x: offset)
                    .shadow(color: .black.opacity(offset > 0 ? 0.16 : 0), radius: offset > 0 ? 12 : 0, x: -3, y: 0)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(width: geometry.size.width))
            }
            .clipped()
        }
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: minimumDistance, coordinateSpace: .local)
            .onChanged { value in
                guard value.startLocation.x <= edgeWidth else { return }
                if directionIsHorizontal == nil {
                    directionIsHorizontal = abs(value.translation.width) > abs(value.translation.height)
                }
                guard directionIsHorizontal == true else { return }
                offset = min(max(value.translation.width, 0), width)
            }
            .onEnded { value in
                defer { directionIsHorizontal = nil }
                guard value.startLocation.x <= edgeWidth, directionIsHorizontal == true else { return }
                let shouldDismiss = offset >= width * dismissFraction
                if animated {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        offset = shouldDismiss ? width : 0
                    }
                } else {
                    offset = shouldDismiss ? width : 0
                }
                if shouldDismiss {
                    onHaptic?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + (animated ? 0.36 : 0)) {
                        onDismiss()
                    }
                }
            }
    }
}

#Preview {
    SwipeBack(onDismiss: {}, background: { Color.blue.ignoresSafeArea() }, content: { Color.orange.ignoresSafeArea() })
        .frame(width: 360, height: 480)
}
