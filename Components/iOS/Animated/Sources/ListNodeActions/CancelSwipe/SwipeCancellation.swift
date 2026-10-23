import SwiftUI

/// Chooses the nearest open detent when SwiftUI cancels a drag before `onEnded` runs.
public enum SwipeCancellation {
    public static func target(offset: CGFloat, leadingWidth: CGFloat, trailingWidth: CGFloat) -> CGFloat {
        if offset > leadingWidth / 2 { return leadingWidth }
        if offset < -trailingWidth / 2 { return -trailingWidth }
        return 0
    }
}
