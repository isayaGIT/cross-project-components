import SwiftUI
import LineDashed

/// The texture drawn inside a CapsuleButton's supplied shape.
public enum CapsuleButtonTexture {
    /// A SwiftUI material surface.
    case material(Material = .ultraThin)
    /// A solid or translucent color surface.
    case color(Color)
    /// A custom surface, such as a Liquid Glass view.
    case custom(AnyView)
}

/// The outline drawn above the texture and below the button content.
public enum CapsuleButtonBorder {
    case none
    case solid(color: Color, lineWidth: CGFloat = 1)
    case dashed(configuration: DashedLineConfiguration = .init(lineWidth: 2.5, dashLength: 8, dashSpacing: 4), color: Color)
    case custom(AnyView)
}

/// Reusable, content-sized button with independently configurable shape and visual layers.
/// Drawing order, from back to front: shape-constrained texture, border, content, decor.
public struct CapsuleButton: View {
    private let title: String
    private let customContent: AnyView?
    private let shape: AnyShape
    private let texture: CapsuleButtonTexture
    private let border: CapsuleButtonBorder
    private let foreground: Color
    private let padding: EdgeInsets
    private let font: Font
    private let decor: AnyView?
    private let action: () -> Void

    public init(
        _ title: String,
        shape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: 18, style: .continuous)),
        texture: CapsuleButtonTexture = .color(Color.primary.opacity(0.07)),
        border: CapsuleButtonBorder = .none,
        foreground: Color = .primary,
        padding: EdgeInsets = EdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14),
        font: Font = .system(size: 14, weight: .medium),
        decor: AnyView? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.customContent = nil
        self.shape = shape
        self.texture = texture
        self.border = border
        self.foreground = foreground
        self.padding = padding
        self.font = font
        self.decor = decor
        self.action = action
    }

    /// Content-based initializer for buttons whose label is not plain text (for example, an icon).
    /// The original string initializer remains source-compatible.
    public init(
        content: AnyView,
        shape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: 18, style: .continuous)),
        texture: CapsuleButtonTexture = .color(Color.primary.opacity(0.07)),
        border: CapsuleButtonBorder = .none,
        foreground: Color = .primary,
        padding: EdgeInsets = EdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14),
        font: Font = .system(size: 14, weight: .medium),
        decor: AnyView? = nil,
        action: @escaping () -> Void
    ) {
        self.title = ""
        self.customContent = content
        self.shape = shape
        self.texture = texture
        self.border = border
        self.foreground = foreground
        self.padding = padding
        self.font = font
        self.decor = decor
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Group {
                if let customContent {
                    customContent
                } else {
                    Text(title)
                }
            }
                .font(font)
                .foregroundStyle(foreground)
                .padding(padding)
                .fixedSize(horizontal: true, vertical: false)
                .background {
                    textureView
                        .clipShape(shape)
                }
                .overlay {
                    borderView
                        .allowsHitTesting(false)
                }
                .overlay {
                    if let decor {
                        decor
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    @ViewBuilder
    private var textureView: some View {
        switch texture {
        case .material(let material):
            Rectangle().fill(material)
        case .color(let color):
            color
        case .custom(let view):
            view
        }
    }

    @ViewBuilder
    private var borderView: some View {
        switch border {
        case .none:
            EmptyView()
        case .solid(let color, let lineWidth):
            shape.stroke(color, lineWidth: lineWidth.isFinite ? max(0, lineWidth) : 0)
        case .dashed(let configuration, let color):
            GeometryReader { geometry in
                let rect = CGRect(origin: .zero, size: geometry.size)
                DashedPath(
                    path: shape.path(in: rect),
                    configuration: configuration,
                    fill: .color(color)
                )
            }
        case .custom(let view):
            view
        }
    }
}

/// Reusable style presets for CapsuleButton.
public enum CapsuleButtonPreset {
    /// Muted gray-pink dashed outline on a softly tinted, smoothed rounded rectangle.
    public static func hanPink(
        _ title: String,
        cornerRadius: CGFloat = 16,
        foreground: Color = Color(red: 0.36, green: 0.28, blue: 0.31),
        padding: EdgeInsets = EdgeInsets(top: 8, leading: 13, bottom: 8, trailing: 13),
        font: Font = .system(size: 14, weight: .medium),
        decor: AnyView? = nil,
        action: @escaping () -> Void
    ) -> CapsuleButton {
        CapsuleButton(
            title,
            shape: AnyShape(RoundedRectSmoothed(cornerRadius: cornerRadius)),
            texture: .color(Color(red: 0.96, green: 0.92, blue: 0.93).opacity(0.9)),
            border: .dashed(
                configuration: DashedLineConfiguration(lineWidth: 2.6, dashLength: 8, dashSpacing: 4, cornerRadius: 1.5),
                color: Color(red: 0.68, green: 0.49, blue: 0.55).opacity(0.92)
            ),
            foreground: foreground,
            padding: padding,
            font: font,
            decor: decor,
            action: action
        )
    }
}
