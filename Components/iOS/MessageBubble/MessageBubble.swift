import SwiftUI

/// The visual silhouette used by `MessageBubble`.
public enum MessageBubbleStyle: Sendable, Equatable {
    /// A rounded rectangle with one optionally square corner. No tail is drawn.
    case tailLess
    /// A rounded rectangle whose lower leading or trailing corner flows into an integrated tail.
    case roundedTail
}

/// Geometry for a message bubble. The optional tail is part of the same path as the body.
public struct MessageBubbleShape: Shape {
    /// The corner that remains square in `tailLess` mode, or selects the tail side in `roundedTail` mode.
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
    public var style: MessageBubbleStyle

    public var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = max(0, newValue) }
    }

    public init(
        cornerRadius: CGFloat = 16,
        sharpCorner: SharpCorner = .bottomTrailing,
        style: MessageBubbleStyle = .tailLess
    ) {
        self.cornerRadius = max(0, cornerRadius)
        self.sharpCorner = sharpCorner
        self.style = style
    }

    public func path(in rect: CGRect) -> Path {
        let radius = min(max(0, cornerRadius), max(0, min(rect.width, rect.height) / 2))
        guard style == .roundedTail,
              rect.width > 0,
              rect.height > 0,
              sharpCorner == .bottomLeading || sharpCorner == .bottomTrailing
        else {
            let radii = RectangleCornerRadii(
                topLeading: sharpCorner == .topLeading ? 0 : radius,
                bottomLeading: sharpCorner == .bottomLeading ? 0 : radius,
                bottomTrailing: sharpCorner == .bottomTrailing ? 0 : radius,
                topTrailing: sharpCorner == .topTrailing ? 0 : radius
            )
            return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous).path(in: rect)
        }

        return tailedPath(in: rect, radius: radius, tailOnLeading: sharpCorner == .bottomLeading)
    }

    private func tailedPath(in rect: CGRect, radius: CGFloat, tailOnLeading: Bool) -> Path {
        // Reserve room inside the shape's bounds for the tail so the content layout needs no overlay.
        let tailHeight = min(8, max(4, rect.height * 0.12))
        let bodyBottom = rect.maxY - tailHeight
        let bodyHeight = max(0, bodyBottom - rect.minY)
        let r = min(radius, min(rect.width / 2, bodyHeight / 2))
        let tailBase = min(18, max(0, rect.width - 2 * r - 4))
        let baseStart = tailOnLeading
            ? rect.minX + r + 2
            : rect.maxX - r - tailBase - 2
        let baseEnd = baseStart + tailBase
        let tipX = tailOnLeading
            ? max(rect.minX, baseStart - 5)
            : min(rect.maxX, baseEnd + 5)
        let k: CGFloat = 0.5522847498
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + r),
            control1: CGPoint(x: rect.maxX - r + r * k, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + r - r * k)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: bodyBottom - r))
        path.addCurve(
            to: CGPoint(x: rect.maxX - r, y: bodyBottom),
            control1: CGPoint(x: rect.maxX, y: bodyBottom - r + r * k),
            control2: CGPoint(x: rect.maxX - r + r * k, y: bodyBottom)
        )

        if tailOnLeading {
            path.addLine(to: CGPoint(x: baseEnd, y: bodyBottom))
            path.addCurve(
                to: CGPoint(x: tipX, y: rect.maxY),
                control1: CGPoint(x: baseEnd - 2, y: bodyBottom + 1),
                control2: CGPoint(x: tipX + 2, y: rect.maxY - tailHeight * 0.18)
            )
            path.addCurve(
                to: CGPoint(x: baseStart, y: bodyBottom - 1),
                control1: CGPoint(x: tipX + 1, y: bodyBottom + tailHeight * 0.3),
                control2: CGPoint(x: baseStart + 1, y: bodyBottom + 2)
            )
        } else {
            path.addLine(to: CGPoint(x: baseStart, y: bodyBottom))
            path.addCurve(
                to: CGPoint(x: tipX, y: rect.maxY),
                control1: CGPoint(x: baseStart + 2, y: bodyBottom + 1),
                control2: CGPoint(x: tipX - 2, y: rect.maxY - tailHeight * 0.18)
            )
            path.addCurve(
                to: CGPoint(x: baseEnd, y: bodyBottom - 1),
                control1: CGPoint(x: tipX - 1, y: bodyBottom + tailHeight * 0.3),
                control2: CGPoint(x: baseEnd - 1, y: bodyBottom + 2)
            )
        }

        path.addLine(to: CGPoint(x: rect.minX + r, y: bodyBottom))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: bodyBottom - r),
            control1: CGPoint(x: rect.minX + r - r * k, y: bodyBottom),
            control2: CGPoint(x: rect.minX, y: bodyBottom - r + r * k)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + r - r * k),
            control2: CGPoint(x: rect.minX + r - r * k, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

/// A reusable, content-agnostic chat bubble with an optional timestamp outside the silhouette.
/// The host app remains responsible for message data, sender grouping, and timestamp formatting.
public struct MessageBubble<Content: View>: View {
    private let cornerRadius: CGFloat
    private let sharpCorner: MessageBubbleShape.SharpCorner
    private let style: MessageBubbleStyle
    private let fill: AnyShapeStyle
    private let padding: EdgeInsets
    private let width: CGFloat?
    private let height: CGFloat?
    private let alignment: Alignment
    private let timestamp: String?
    private let metadataAlignment: HorizontalAlignment
    private let timestampColor: Color
    private let timestampFont: Font
    private let content: Content

    /// Creates a bubble using the system accent color.
    public init(
        cornerRadius: CGFloat = 16,
        sharpCorner: MessageBubbleShape.SharpCorner = .bottomTrailing,
        style: MessageBubbleStyle = .tailLess,
        padding: EdgeInsets = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14),
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        alignment: Alignment = .leading,
        timestamp: String? = nil,
        metadataAlignment: HorizontalAlignment = .trailing,
        timestampColor: Color = .secondary,
        timestampFont: Font = .caption2,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            cornerRadius: cornerRadius,
            sharpCorner: sharpCorner,
            style: style,
            fill: Color.accentColor,
            padding: padding,
            width: width,
            height: height,
            alignment: alignment,
            timestamp: timestamp,
            metadataAlignment: metadataAlignment,
            timestampColor: timestampColor,
            timestampFont: timestampFont,
            content: content
        )
    }

    /// Creates a bubble with any SwiftUI shape style, including colors and gradients.
    public init<S: ShapeStyle>(
        cornerRadius: CGFloat = 16,
        sharpCorner: MessageBubbleShape.SharpCorner = .bottomTrailing,
        style: MessageBubbleStyle = .tailLess,
        fill: S,
        padding: EdgeInsets = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14),
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        alignment: Alignment = .leading,
        timestamp: String? = nil,
        metadataAlignment: HorizontalAlignment = .trailing,
        timestampColor: Color = .secondary,
        timestampFont: Font = .caption2,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = max(0, cornerRadius)
        self.sharpCorner = sharpCorner
        self.style = style
        self.fill = AnyShapeStyle(fill)
        self.padding = padding
        self.width = width
        self.height = height
        self.alignment = alignment
        self.timestamp = timestamp.flatMap { $0.isEmpty ? nil : $0 }
        self.metadataAlignment = metadataAlignment
        self.timestampColor = timestampColor
        self.timestampFont = timestampFont
        self.content = content()
    }

    private var bubbleShape: MessageBubbleShape {
        MessageBubbleShape(cornerRadius: cornerRadius, sharpCorner: sharpCorner, style: style)
    }

    public var body: some View {
        VStack(alignment: metadataAlignment, spacing: 4) {
            content
                .padding(padding)
                .frame(width: width, height: height, alignment: alignment)
                .background {
                    bubbleShape.fill(fill)
                }
                .contentShape(bubbleShape)

            if let timestamp {
                Text(timestamp)
                    .font(timestampFont)
                    .foregroundStyle(timestampColor)
                    .fixedSize()
                    .accessibilityLabel("Sent at \(timestamp)")
            }
        }
    }
}
