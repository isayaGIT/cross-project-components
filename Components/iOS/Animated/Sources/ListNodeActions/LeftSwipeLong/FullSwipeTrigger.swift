import SwiftUI

/// Full-swipe threshold from the original implementation: 60% of the row, at least two action tiles.
public enum FullSwipeTrigger {
    public static func threshold(rowWidth: CGFloat, tileWidth: CGFloat) -> CGFloat {
        max(rowWidth * 0.6, tileWidth * 2)
    }

    public static func isTriggered(offset: CGFloat, threshold: CGFloat) -> Bool {
        abs(offset) > threshold
    }
}
