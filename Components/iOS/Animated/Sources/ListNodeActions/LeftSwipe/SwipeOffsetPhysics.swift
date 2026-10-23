import SwiftUI

/// Offset resistance extracted from the original SwipeActionRow drag implementation.
public enum SwipeOffsetPhysics {
    public static func offset(_ x: CGFloat, hasActions: Bool, fullSwipeThreshold: CGFloat, revealedWidth: CGFloat) -> CGFloat {
        guard hasActions else { return rubberBand(x, limit: 60) }
        let free = max(fullSwipeThreshold, revealedWidth)
        return rubberBand(x, in: -free...free, limit: 80)
    }

    public static func rubberBand(_ overshoot: CGFloat, limit: CGFloat, coefficient: CGFloat = 0.55) -> CGFloat {
        guard limit > 0, overshoot != 0 else { return 0 }
        let banded = (1 - 1 / (abs(overshoot) * coefficient / limit + 1)) * limit
        return overshoot < 0 ? -banded : banded
    }

    public static func rubberBand(_ value: CGFloat, in range: ClosedRange<CGFloat>, limit: CGFloat, coefficient: CGFloat = 0.55) -> CGFloat {
        if value < range.lowerBound { return range.lowerBound + rubberBand(value - range.lowerBound, limit: limit, coefficient: coefficient) }
        if value > range.upperBound { return range.upperBound + rubberBand(value - range.upperBound, limit: limit, coefficient: coefficient) }
        return value
    }
}
