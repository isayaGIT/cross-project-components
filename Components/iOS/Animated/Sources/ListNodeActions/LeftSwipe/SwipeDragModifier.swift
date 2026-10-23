import SwiftUI

public enum SwipeGestureEdge { case leading, trailing }

/// Action metadata passed from a row to the gesture layer. It contains no presentation styling.
public struct SwipeDragAction {
    public let isDestructive: Bool
    public let handler: () -> Void

    public init(isDestructive: Bool, handler: @escaping () -> Void) {
        self.isDestructive = isDestructive
        self.handler = handler
    }
}

/// Owns horizontal drag recognition, finger tracking, release projection, and cancellation recovery.
/// Deliberately contains no row layout, button, color, glass, or other presentation code.
public struct SwipeDragModifier: ViewModifier {
    @Binding private var offset: CGFloat
    @Binding private var dragStart: CGFloat?
    @Binding private var grabbedAt: Date
    @Binding private var armed: Bool
    @Binding private var arms: Int
    @Binding private var swallowed: Bool
    @Binding private var leaving: Bool
    @GestureState private var dragging = false

    private let leadingWidth: CGFloat
    private let trailingWidth: CGFloat
    private let fullSwipeThreshold: CGFloat
    private let reduceMotion: Bool
    private let cardOffset: (CGFloat) -> CGFloat
    private let fullSwipeAction: () -> SwipeDragAction?
    private let claimRow: () -> Void
    private let settle: (SwipeGestureEdge?, CGFloat?) -> Void
    private let leave: (CGFloat) -> Void

    public init(
        offset: Binding<CGFloat>, dragStart: Binding<CGFloat?>, grabbedAt: Binding<Date>,
        armed: Binding<Bool>, arms: Binding<Int>, swallowed: Binding<Bool>, leaving: Binding<Bool>,
        leadingWidth: CGFloat, trailingWidth: CGFloat, fullSwipeThreshold: CGFloat, reduceMotion: Bool,
        cardOffset: @escaping (CGFloat) -> CGFloat,
        fullSwipeAction: @escaping () -> SwipeDragAction?, claimRow: @escaping () -> Void,
        settle: @escaping (SwipeGestureEdge?, CGFloat?) -> Void, leave: @escaping (CGFloat) -> Void
    ) {
        _offset = offset; _dragStart = dragStart; _grabbedAt = grabbedAt
        _armed = armed; _arms = arms; _swallowed = swallowed; _leaving = leaving
        self.leadingWidth = leadingWidth; self.trailingWidth = trailingWidth
        self.fullSwipeThreshold = fullSwipeThreshold; self.reduceMotion = reduceMotion
        self.cardOffset = cardOffset; self.fullSwipeAction = fullSwipeAction
        self.claimRow = claimRow; self.settle = settle; self.leave = leave
    }

    public func body(content: Content) -> some View {
        content
            .gesture(drag)
            .onChange(of: dragging) { _, active in
                guard !active, dragStart != nil else { return }
                dragStart = nil
                armed = false
                let target = SwipeCancellation.target(offset: offset, leadingWidth: leadingWidth, trailingWidth: trailingWidth)
                settle(target > 0 ? .leading : target < 0 ? .trailing : nil, nil)
            }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragging) { _, active, _ in active = true }
            .onChanged { value in
                guard !leaving else { return }
                if dragStart == nil {
                    // Vertical drags belong to the containing scroll view.
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragStart = offset
                    grabbedAt = value.time
                    claimRow()
                }
                guard let dragStart else { return }
                let next = cardOffset(dragStart + value.translation.width)
                if value.time.timeIntervalSince(grabbedAt) < 0.1 {
                    withAnimation(.spring(duration: 0.14, bounce: 0)) { offset = next }
                } else {
                    offset = next
                }
                let nowArmed = fullSwipeAction() != nil
                if nowArmed != armed {
                    armed = nowArmed
                    if nowArmed { arms += 1 }
                }
                if swallowed != nowArmed { swallowed = nowArmed }
            }
            .onEnded { value in
                guard let start = dragStart else { return }
                dragStart = nil
                let x = start + value.translation.width
                let speed = (cardOffset(x + value.velocity.width * 0.01) - cardOffset(x)) / 0.01
                if let action = fullSwipeAction() {
                    if action.isDestructive {
                        leave(speed)
                    } else {
                        armed = false
                        settle(nil, speed)
                    }
                    action.handler()
                    return
                }
                let projected = start + value.predictedEndTranslation.width
                if projected > leadingWidth / 2 { settle(.leading, speed) }
                else if projected < -trailingWidth / 2 { settle(.trailing, speed) }
                else { settle(nil, speed) }
            }
    }
}
