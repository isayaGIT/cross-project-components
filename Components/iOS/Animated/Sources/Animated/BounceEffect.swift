import SwiftUI

/// A compact, reusable bounce for content that changes state.
/// Inspired by the symbol/content bounce choreography in SwiftPieces' Reaction Toggle.
/// https://swiftpieces.com/docs/components/feedback/reaction-toggle
public struct BounceEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let trigger: Int
    private let amount: CGFloat

    public init(trigger: Int, amount: CGFloat = 0.12) {
        self.trigger = trigger
        self.amount = min(max(amount, 0), 0.5)
    }

    public func body(content: Content) -> some View {
        let shouldReduceMotion = reduceMotion
        return content
            .keyframeAnimator(initialValue: Bounce(), trigger: trigger) { view, value in
                view.scaleEffect(shouldReduceMotion ? 1 : value.scale)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1 - amount * 0.55, duration: 0.08)
                    SpringKeyframe(1 + amount, duration: 0.18, spring: .snappy)
                    SpringKeyframe(1, duration: 0.34, spring: .bouncy)
                }
            }
    }

    private struct Bounce {
        var scale: CGFloat = 1
    }
}

public extension View {
    /// Bounces the content when `trigger` changes. Increment only when the content should bounce.
    func bounceEffect(trigger: Int, amount: CGFloat = 0.12) -> some View {
        modifier(BounceEffect(trigger: trigger, amount: amount))
    }
}
