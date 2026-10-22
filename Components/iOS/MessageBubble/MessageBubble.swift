import SwiftUI

/// A rounded rectangle whose selected corner can be square without adding a separate tail.
///
/// Keep this shape independent from message content so it can also be used directly with
/// `fill`, `stroke`, `clipShape`, and other standard SwiftUI shape APIs.
public struct MessageBubbleShape: Shape {
    /// The corner that should remain square. `.none` keeps all four corners rounded.
    public enum SharpCorner: Sendable, Equatable {
        case none
        case topLeading
        case topTrailing
        case bottomLeading
        case bottomTrailing
    }

    public var cornerRadius: CGFloat {
        didSet { cornerRadius = max(0, cornerRadius) }
    }
    public var sharpCorner: SharpCorner

    public var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = max(0, newValue) }
    }

    public init(
        cornerRadius: CGFloat = 16,
        sharpCorner: SharpCorner = .none
    ) {
        self.cornerRadius = max(0, cornerRadius)
        self.sharpCorner = sharpCorner
    }

    public func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, max(0, min(rect.width, rect.height) / 2))
        let square: CGFloat = 0

        let radii = RectangleCornerRadii(
            topLeading: sharpCorner == .topLeading ? square : radius,
            bottomLeading: sharpCorner == .bottomLeading ? square : radius,
            bottomTrailing: sharpCorner == .bottomTrailing ? square : radius,
            topTrailing: sharpCorner == .topTrailing ? square : radius
        )

        return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous)
            .path(in: rect)
    }
}

/// A lightweight, content-agnostic message bubble.
///
/// The caller owns message data, typography, layout outside the bubble, and interactions.
/// Use the content closure to provide any SwiftUI view; use ordinary view modifiers for
/// typography and visual effects rather than coupling them to this component.
public struct MessageBubble<Content: View>: View {
    private let shape: MessageBubbleShape
    private let fill: AnyShapeStyle
    private let padding: EdgeInsets
    private let width: CGFloat?
    private let height: CGFloat?
    private let alignment: Alignment
    private let content: Content

    /// Creates a bubble using the system accent color.
    public init(
        cornerRadius: CGFloat = 16,
        sharpCorner: MessageBubbleShape.SharpCorner = .bottomTrailing,
        padding: EdgeInsets = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14),
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        alignment: Alignment = .leading,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            cornerRadius: cornerRadius,
            sharpCorner: sharpCorner,
            fill: Color.accentColor,
            padding: padding,
            width: width,
            height: height,
            alignment: alignment,
            content: content
        )
    }

    /// Creates a bubble with any SwiftUI shape style, including colors and gradients.
    public init<S: ShapeStyle>(
        cornerRadius: CGFloat = 16,
        sharpCorner: MessageBubbleShape.SharpCorner = .bottomTrailing,
        fill: S,
        padding: EdgeInsets = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14),
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        alignment: Alignment = .leading,
        @ViewBuilder content: () -> Content
    ) {
        self.shape = MessageBubbleShape(cornerRadius: cornerRadius, sharpCorner: sharpCorner)
        self.fill = AnyShapeStyle(fill)
        self.padding = padding
        self.width = width
        self.height = height
        self.alignment = alignment
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(width: width, height: height, alignment: alignment)
            .background {
                shape.fill(fill)
            }
            .contentShape(shape)
    }
}
