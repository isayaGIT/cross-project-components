import SwiftUI
import LineDashed

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


/// Optional outline rendered on the same final geometry as the message bubble.
public enum MessageBubbleBorder {
    case none
    case solid(color: Color, lineWidth: CGFloat = 1)
    case dashed(
        configuration: DashedLineConfiguration = .init(),
        fill: DashedLineFill = .color(.primary),
        fillCoordinates: DashedLineFillCoordinates = .pathContinuous,
        phase: CGFloat = 0
    )
}

/// A reusable, content-agnostic chat bubble with an optional timestamp outside the silhouette.
/// The host app remains responsible for message data, sender grouping, and timestamp formatting.
public struct MessageBubble<Content: View>: View {
    /// Complete configuration for a message bubble, including its timestamp presentation.
    public struct Configuration {
        public var cornerRadius: CGFloat
        public var sharpCorner: MessageBubbleShape.SharpCorner
        public var style: MessageBubbleStyle
        public var fill: AnyShapeStyle
        public var border: MessageBubbleBorder
        public var padding: EdgeInsets
        public var width: CGFloat?
        public var height: CGFloat?
        public var alignment: Alignment
        public var timestamp: String?
        public var metadataAlignment: HorizontalAlignment
        public var timestampColor: Color
        public var timestampFont: Font
        public var font: Font
        public var lineSpacing: CGFloat

        public init(
            cornerRadius: CGFloat = 16,
            sharpCorner: MessageBubbleShape.SharpCorner = .bottomTrailing,
            style: MessageBubbleStyle = .tailLess,
            fill: AnyShapeStyle = AnyShapeStyle(Color.accentColor),
            border: MessageBubbleBorder = .none,
            padding: EdgeInsets = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14),
            width: CGFloat? = nil,
            height: CGFloat? = nil,
            alignment: Alignment = .leading,
            timestamp: String? = nil,
            metadataAlignment: HorizontalAlignment = .trailing,
            timestampColor: Color = .secondary,
            timestampFont: Font = .caption2,
            font: Font = .body,
            lineSpacing: CGFloat = 0
        ) {
            self.cornerRadius = cornerRadius
            self.sharpCorner = sharpCorner
            self.style = style
            self.fill = fill
            self.border = border
            self.padding = padding
            self.width = width
            self.height = height
            self.alignment = alignment
            self.timestamp = timestamp
            self.metadataAlignment = metadataAlignment
            self.timestampColor = timestampColor
            self.timestampFont = timestampFont
            self.font = font
            self.lineSpacing = lineSpacing
        }
    }
    private let cornerRadius: CGFloat
    private let sharpCorner: MessageBubbleShape.SharpCorner
    private let style: MessageBubbleStyle
    private let fill: AnyShapeStyle
    private let border: MessageBubbleBorder
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
        border: MessageBubbleBorder = .none,
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
            border: border,
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
        border: MessageBubbleBorder = .none,
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
        self.border = border
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

    public init<S: ShapeStyle>(
        configuration: Configuration,
        fill: S,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            cornerRadius: configuration.cornerRadius,
            sharpCorner: configuration.sharpCorner,
            style: configuration.style,
            fill: fill,
            border: configuration.border,
            padding: configuration.padding,
            width: configuration.width,
            height: configuration.height,
            alignment: configuration.alignment,
            timestamp: configuration.timestamp,
            metadataAlignment: configuration.metadataAlignment,
            timestampColor: configuration.timestampColor,
            timestampFont: configuration.timestampFont,
            font: configuration.font,
            lineSpacing: configuration.lineSpacing,
            content: content
        )
    }

    public init(configuration: Configuration, @ViewBuilder content: () -> Content) {
        self.init(
            cornerRadius: configuration.cornerRadius,
            sharpCorner: configuration.sharpCorner,
            style: configuration.style,
            fill: configuration.fill,
            border: configuration.border,
            padding: configuration.padding,
            width: configuration.width,
            height: configuration.height,
            alignment: configuration.alignment,
            timestamp: configuration.timestamp,
            metadataAlignment: configuration.metadataAlignment,
            timestampColor: configuration.timestampColor,
            timestampFont: configuration.timestampFont,
            font: configuration.font,
            lineSpacing: configuration.lineSpacing,
            content: content
        )
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
                .overlay {
                    GeometryReader { geometry in
                        switch border {
                        case .none:
                            EmptyView()
                        case .solid(let color, let lineWidth):
                            bubbleShape
                                .stroke(color, lineWidth: lineWidth.isFinite ? max(0, lineWidth) : 0)
                        case .dashed(let configuration, let dashFill, let coordinates, let phase):
                            // Canvas clips to its own rectangular bounds. Give it an 8pt
                            // bleed area (the tail is 6pt wide), then translate the original
                            // zero-origin shape into that area. RoundedRectSmoothed's tail
                            // geometry assumes a zero-origin rect; passing an inset rect
                            // directly mixes minX/minY with width/height and distorts the path.
                            let bleed: CGFloat = 8
                            let bubbleSize = CGSize(
                                width: max(0, geometry.size.width - bleed * 2),
                                height: max(0, geometry.size.height - bleed * 2)
                            )
                            let basePath = bubbleShape.path(in: CGRect(origin: .zero, size: bubbleSize))
                            let expandedPath = basePath.applying(
                                CGAffineTransform(translationX: bleed, y: bleed)
                            )
                            DashedPath(
                                path: expandedPath,
                                configuration: configuration,
                                fill: dashFill,
                                fillCoordinates: coordinates,
                                phase: phase
                            )
                        }
                    }
                    .padding(-8)
                    .allowsHitTesting(false)
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
