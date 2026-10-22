import SwiftUI

/// Owns the insertion/removal motion for bottom-aligned surfaces.
/// Apply `slideDownDismiss(isPresented:)` to the presented surface.
public enum SlideDownDismiss {
    public static let duration: Double = 0.32
    public static let animation = Animation.interactiveSpring(response: duration, dampingFraction: 0.9)
    /// Keep dismissal to one motion: no opacity phase competing with the slide.
    public static let transition: AnyTransition = .move(edge: .bottom)
}

private struct SlideDownDismissModifier: ViewModifier {
    let isPresented: Bool

    func body(content: Content) -> some View {
        content
            .transition(SlideDownDismiss.transition)
            .animation(SlideDownDismiss.animation, value: isPresented)
    }
}

public extension View {
    /// Applies SlideDownDismiss's transition and animation as one reusable behavior.
    func slideDownDismiss(isPresented: Bool) -> some View {
        modifier(SlideDownDismissModifier(isPresented: isPresented))
    }
}
