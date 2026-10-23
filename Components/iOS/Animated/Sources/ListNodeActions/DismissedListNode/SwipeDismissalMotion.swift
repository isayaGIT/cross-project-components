import SwiftUI

/// Computes the outgoing position and prevents inward velocity from carrying a destructive swipe.
public enum SwipeDismissalMotion {
    public static func target(offset: CGFloat, rowWidth: CGFloat, fade: CGFloat) -> CGFloat {
        (offset > 0 ? 1 : -1) * (rowWidth + fade + 24)
    }

    public static func outwardVelocity(target: CGFloat, velocity: CGFloat) -> CGFloat {
        target > 0 ? max(velocity, 0) : min(velocity, 0)
    }
}
