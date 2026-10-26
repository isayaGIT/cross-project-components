import SwiftUI

/// Connects a message bubble to the owned fan menu without putting menu choreography into MessageBubble itself.
/// A native LongPress → Drag sequence keeps one touch alive from activation through release. Moving beyond the
/// tolerance before the hold completes lets the surrounding ScrollView take over normally.
public struct MessageBubbleActionMenuModifier: ViewModifier {
    private let items: [MessageBubbleGlassActionMenu.Item]
    private let arrangement: MessageBubbleGlassActionMenu.Arrangement
    private let tint: Color?
    private let style: MessageBubbleGlassActionMenu.Style
    private let holdDuration: Duration
    private let movementTolerance: CGFloat

    @State private var menuVisible = false
    @State private var activated = false
    @State private var receivedEnd = false
    @State private var origin: CGPoint = .zero
    @State private var bubbleSize: CGSize = .zero
    @State private var latestLocation: CGPoint = .zero
    @State private var gestureID = UUID()
    @State private var sequence = 0
    @State private var externalGesture: MessageBubbleGlassActionMenu.ExternalGesture?
    @GestureState private var gestureInProgress = false

    public init(
        items: [MessageBubbleGlassActionMenu.Item],
        arrangement: MessageBubbleGlassActionMenu.Arrangement = .arc,
        tint: Color? = nil,
        style: MessageBubbleGlassActionMenu.Style = .standard,
        holdDuration: Duration = .milliseconds(350),
        movementTolerance: CGFloat = 12
    ) {
        self.items = items
        self.arrangement = arrangement
        self.tint = tint
        self.style = style
        self.holdDuration = holdDuration
        self.movementTolerance = max(0, movementTolerance)
    }

    private var holdSwipeGesture: some Gesture {
        LongPressGesture(
            minimumDuration: max(0, Double(holdDuration.components.seconds) + Double(holdDuration.components.attoseconds) / 1_000_000_000_000_000_000),
            maximumDistance: movementTolerance
        )
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .updating($gestureInProgress) { _, state, _ in state = true }
            .onChanged { value in
                switch value {
                case .first(true):
                    // LongPressGesture confirms while the finger is still down. Anchor at the bubble center,
                    // which is stable even before the sequenced DragGesture has emitted its first location.
                    if !activated {
                        activate(at: CGPoint(x: bubbleSize.width / 2, y: bubbleSize.height / 2))
                    }
                case .second(true, let drag?):
                    if !activated {
                        activate(at: CGPoint(x: bubbleSize.width / 2, y: bubbleSize.height / 2))
                    }
                    latestLocation = drag.location
                    send(.changed, location: drag.location)
                default:
                    break
                }
            }
            .onEnded { value in
                receivedEnd = true
                guard activated, case .second(true, let drag?) = value else {
                    if activated { send(.cancelled, location: latestLocation) }
                    else { resetGesture() }
                    return
                }
                latestLocation = drag.location
                send(.ended, location: drag.location)
            }
    }

    private func activate(at anchor: CGPoint) {
        activated = true
        receivedEnd = false
        origin = anchor
        gestureID = UUID()
        sequence = 0
        menuVisible = true
        send(.activated, location: anchor)
    }

    public func body(content: Content) -> some View {
        content
            // The system's text-selection loupe/context menu otherwise competes with a message long-press.
            // This modifier is opt-in, so disable selection only when message actions are enabled.
            .textSelection(.disabled)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { bubbleSize = proxy.size }
                        .onChange(of: proxy.size) { _, size in bubbleSize = size }
                }
            }
            .highPriorityGesture(holdSwipeGesture)
            .overlay(alignment: .topLeading) {
                if menuVisible {
                    MessageBubbleGlassActionMenu(
                        items: items,
                        arrangement: arrangement,
                        tint: tint,
                        style: style,
                        externalGesture: $externalGesture,
                        onExternalDismiss: finishMenu
                    )
                    .position(x: origin.x, y: origin.y)
                    // The bubble owns the complete touch. The menu receives pointer updates through the binding,
                    // so appearing under the finger never steals the gesture or forces a second tap.
                    .allowsHitTesting(false)
                }
            }
            .onChange(of: gestureInProgress) { _, active in
                guard !active, activated, !receivedEnd else { return }
                send(.cancelled, location: latestLocation)
            }
    }

    private func send(_ phase: MessageBubbleGlassActionMenu.ExternalGesture.Phase, location: CGPoint) {
        sequence += 1
        externalGesture = MessageBubbleGlassActionMenu.ExternalGesture(
            id: gestureID,
            sequence: sequence,
            phase: phase,
            origin: origin,
            location: location
        )
    }

    private func finishMenu() {
        menuVisible = false
        resetGesture()
    }

    private func resetGesture() {
        externalGesture = nil
        menuVisible = false
        activated = false
        receivedEnd = false
    }
}

public extension View {
    /// Call on a message bubble to enable one continuous hold → swipe → release action.
    func messageBubbleActions(
        items: [MessageBubbleGlassActionMenu.Item],
        arrangement: MessageBubbleGlassActionMenu.Arrangement = .arc,
        tint: Color? = nil,
        style: MessageBubbleGlassActionMenu.Style = .standard,
        holdDuration: Duration = .milliseconds(350),
        movementTolerance: CGFloat = 12
    ) -> some View {
        modifier(MessageBubbleActionMenuModifier(
            items: items,
            arrangement: arrangement,
            tint: tint,
            style: style,
            holdDuration: holdDuration,
            movementTolerance: movementTolerance
        ))
    }
}
