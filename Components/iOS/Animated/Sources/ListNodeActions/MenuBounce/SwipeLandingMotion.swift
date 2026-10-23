import SwiftUI

/// Release-velocity handling for the original swipe-row spring landing.
public enum SwipeLandingMotion {
    public static func closingSpring() -> Spring { Spring(duration: 0.28, bounce: 0) }

    public static func carriedVelocity(target: CGFloat, current: CGFloat, velocity: CGFloat, spring: Spring) -> CGFloat {
        let reach = (target - current) * 2 * .pi / spring.duration
        if target == 0 { return velocity }
        return reach < 0 ? max(velocity, reach) : min(velocity, reach)
    }
}
