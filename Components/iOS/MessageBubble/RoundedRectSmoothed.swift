import SwiftUI

/// A reusable message-bubble silhouette backed by the single-path Bubble shape
/// from c-villain/Shapes. The body and tail share one outline, so no seam is stroked.
public struct RoundedRectSmoothed: Shape {
    public enum Tail: Sendable, Equatable { case none, leading, trailing }

    public var cornerRadius: CGFloat
    public var tail: Tail
    public var tailWidth: CGFloat
    public var tailHeight: CGFloat
    public var sharpCorner: SharpCorner

    public enum SharpCorner: Sendable, Equatable { case none, topLeading, topTrailing, bottomLeading, bottomTrailing }

    public init(cornerRadius: CGFloat = 18, tail: Tail = .none, tailWidth: CGFloat = 6, tailHeight: CGFloat = 12, sharpCorner: SharpCorner = .none) {
        self.cornerRadius = max(0, cornerRadius)
        self.tail = tail
        self.tailWidth = max(0, tailWidth)
        self.tailHeight = max(0, tailHeight)
        self.sharpCorner = sharpCorner
    }

    public func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        guard tail != .none, tailWidth > 0, tailHeight > 0 else {
            return UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(
                topLeading: sharpCorner == .topLeading ? 0 : cornerRadius,
                bottomLeading: sharpCorner == .bottomLeading ? 0 : cornerRadius,
                bottomTrailing: sharpCorner == .bottomTrailing ? 0 : cornerRadius,
                topTrailing: sharpCorner == .topTrailing ? 0 : cornerRadius
            ), style: .continuous).path(in: rect)
        }

        // BubbleBottomRight is the original c-villain/Shapes single closed contour.
        // Its tail grows outside the body rect; reduce it slightly for a restrained iMessage-style tip.
        let source = BubbleBottomRight(
            cornerRadius: cornerRadius,
            tail: (width: tailWidth, height: min(tailHeight, rect.height))
        ).path(in: rect)

        guard tail == .leading else { return source }
        return source.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rect.minX + rect.maxX, ty: 0))
    }
}
