import SwiftUI

/// The visual silhouette used by `MessageBubble`, backed by the reusable shape in Shapes/RoundedRectSmoothed.
public enum MessageBubbleStyle: Sendable, Equatable {
    /// A rounded rectangle with one optionally square corner. No tail is drawn.
    case tailLess
    /// A rounded rectangle whose lower leading or trailing corner flows into an integrated tail.
    case roundedTail
}

public struct MessageBubbleShape: Shape {
    public enum SharpCorner: Sendable, Equatable {
        case none, topLeading, topTrailing, bottomLeading, bottomTrailing
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

    public init(cornerRadius: CGFloat = 16, sharpCorner: SharpCorner = .bottomTrailing, style: MessageBubbleStyle = .tailLess) {
        self.cornerRadius = max(0, cornerRadius)
        self.sharpCorner = sharpCorner
        self.style = style
    }

    public func path(in rect: CGRect) -> Path {
        let radius = min(max(0, cornerRadius), max(0, min(rect.width, rect.height) / 2))
        let supportsTail = style == .roundedTail &&
            (sharpCorner == .bottomLeading || sharpCorner == .bottomTrailing)
        let tail: RoundedRectSmoothed.Tail = supportsTail
            ? (sharpCorner == .bottomLeading ? .leading : .trailing)
            : .none
        let corner: RoundedRectSmoothed.SharpCorner = {
            switch sharpCorner {
            case .none: return .none
            case .topLeading: return .topLeading
            case .topTrailing: return .topTrailing
            case .bottomLeading: return .bottomLeading
            case .bottomTrailing: return .bottomTrailing
            }
        }()
        return RoundedRectSmoothed(
            cornerRadius: radius,
            tail: tail,
            tailWidth: 6,
            tailHeight: min(12, max(8, rect.height * 0.14)),
            sharpCorner: corner
        ).path(in: rect)
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
    private let font: Font
    private let lineSpacing: CGFloat
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
        font: Font = .body,
        lineSpacing: CGFloat = 0,
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
            font: font,
            lineSpacing: lineSpacing,
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
        font: Font = .body,
        lineSpacing: CGFloat = 0,
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
        self.font = font
        self.lineSpacing = max(0, lineSpacing)
        self.content = content()
    }

    private var bubbleShape: MessageBubbleShape {
        MessageBubbleShape(cornerRadius: cornerRadius, sharpCorner: sharpCorner, style: style)
    }

    public var body: some View {
        VStack(alignment: metadataAlignment, spacing: 4) {
            content
                .font(font)
                .lineSpacing(lineSpacing)
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
