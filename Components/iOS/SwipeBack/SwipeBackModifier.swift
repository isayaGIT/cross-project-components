import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Right-edge-independent, leading-screen-edge swipe-back behavior extracted
/// from ZPing's chat/file overlay modifier.
///
/// Attach it to a full-screen view. The view follows a horizontal drag that
/// begins near the left edge. Vertical scrolling is yielded to the child, and
/// the view either springs back or dismisses after crossing a distance/velocity
/// threshold. The host owns navigation and passes its presentation binding.
public struct SwipeBackModifier: ViewModifier {
    @Binding private var isPresented: Bool
    private var scrollDisabled: Binding<Bool>?
    private let edgeRatio: CGFloat
    private let dismissThresholdRatio: CGFloat
    private let velocityThresholdRatio: CGFloat
    private let shadowRadius: CGFloat
    private let animationResponse: Double
    private let dampingFraction: Double
    private let onHaptic: (() -> Void)?

    @State private var dragOffset: CGFloat = 0
    @State private var isDismissing = false
    @GestureState private var isSwipeActive = false

    public init(
        isPresented: Binding<Bool>,
        scrollDisabled: Binding<Bool>? = nil,
        edgeRatio: CGFloat = 0.08,
        dismissThresholdRatio: CGFloat = 0.3,
        velocityThresholdRatio: CGFloat = 0.5,
        shadowRadius: CGFloat = 8,
        animationResponse: Double = 0.34,
        dampingFraction: Double = 0.86,
        onHaptic: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.scrollDisabled = scrollDisabled
        self.edgeRatio = min(max(edgeRatio, 0.01), 0.5)
        self.dismissThresholdRatio = min(max(dismissThresholdRatio, 0.1), 0.9)
        self.velocityThresholdRatio = min(max(velocityThresholdRatio, 0.1), 1.5)
        self.shadowRadius = max(0, shadowRadius)
        self.animationResponse = max(0.05, animationResponse)
        self.dampingFraction = min(max(dampingFraction, 0.1), 1)
        self.onHaptic = onHaptic
    }

    public func body(content: Content) -> some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width

            content
                .frame(width: screenWidth)
                .frame(maxHeight: .infinity)
                .offset(x: dragOffset)
                .shadow(radius: dragOffset > 0 ? shadowRadius : 0)
                .simultaneousGesture(swipeBackGesture(screenWidth: screenWidth))
                .onChangeCompat(of: isSwipeActive) { active in
                    if !active { scrollDisabled?.wrappedValue = false }
                }
        }
        .onChangeCompat(of: isPresented) { presented in
            if presented {
                isDismissing = false
                dragOffset = 0
            } else {
                scrollDisabled?.wrappedValue = false
            }
        }
    }

    private func swipeBackGesture(screenWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($isSwipeActive) { value, state, _ in
                guard value.startLocation.x < screenWidth * edgeRatio else { return }
                if value.translation.width > 0,
                   value.translation.width > abs(value.translation.height) {
                    state = true
                }
            }
            .onChanged { value in
                guard value.startLocation.x < screenWidth * edgeRatio else { return }
                guard !isDismissing else { return }
                let dx = value.translation.width
                guard dx > 0, dx > abs(value.translation.height) else { return }
                scrollDisabled?.wrappedValue = true
                dragOffset = max(0, dx)
            }
            .onEnded { value in
                guard value.startLocation.x < screenWidth * edgeRatio else { return }
                defer { scrollDisabled?.wrappedValue = false }
                guard !isDismissing else { return }

                let shouldDismiss =
                    value.translation.width > screenWidth * dismissThresholdRatio
                    || value.predictedEndTranslation.width > screenWidth * velocityThresholdRatio

                if shouldDismiss {
                    dismiss(screenWidth: screenWidth)
                } else {
                    withAnimation(.spring(response: animationResponse, dampingFraction: dampingFraction)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func dismiss(screenWidth: CGFloat) {
        guard !isDismissing else { return }
        isDismissing = true
        playHaptic()
        withAnimation(.spring(response: animationResponse, dampingFraction: dampingFraction)) {
            dragOffset = screenWidth
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + animationResponse) {
            isPresented = false
        }
    }

    private func playHaptic() {
        if let onHaptic {
            onHaptic()
            return
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

public extension View {
    /// Adds ZPing's leading-edge swipe-back interaction to a full-screen view.
    ///
    /// - Parameters:
    ///   - isPresented: Set to `false` after a successful swipe to dismiss the view.
    ///   - scrollDisabled: Optional binding set to `true` while a horizontal
    ///     swipe is active, allowing nested scrolling to pause during the gesture.
    ///   - edgeRatio: Leading edge hit-zone width as a fraction of the view width.
    ///   - dismissThresholdRatio: Distance fraction required to dismiss.
    ///   - velocityThresholdRatio: Predicted distance fraction required to dismiss.
    ///   - onHaptic: Optional host-provided haptic override.
    func swipeBack(
        isPresented: Binding<Bool>,
        scrollDisabled: Binding<Bool>? = nil,
        edgeRatio: CGFloat = 0.08,
        dismissThresholdRatio: CGFloat = 0.3,
        velocityThresholdRatio: CGFloat = 0.5,
        onHaptic: (() -> Void)? = nil
    ) -> some View {
        modifier(SwipeBackModifier(
            isPresented: isPresented,
            scrollDisabled: scrollDisabled,
            edgeRatio: edgeRatio,
            dismissThresholdRatio: dismissThresholdRatio,
            velocityThresholdRatio: velocityThresholdRatio,
            onHaptic: onHaptic
        ))
    }
}
