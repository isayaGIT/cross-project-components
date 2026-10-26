import SwiftUI

/// A compact, reusable icon button backed by the shared CapsuleButton drawing layers.
/// The icon may be an SF Symbol, emoji, or any custom SwiftUI view (including a rendered HTML icon).
public struct ButtonCustom: View {
    private let icon: AnyView
    private let color: Color
    private let size: CGSize
    private let shape: AnyShape
    private let texture: CapsuleButtonTexture
    private let border: CapsuleButtonBorder
    private let decor: AnyView?
    private let accessibilityLabel: String
    private let action: () -> Void

    /// Create a button with arbitrary SwiftUI icon content.
    public init(
        icon: AnyView,
        color: Color = .primary,
        size: CGFloat = 40,
        shape: AnyShape? = nil,
        texture: CapsuleButtonTexture = .color(Color.primary.opacity(0.07)),
        border: CapsuleButtonBorder = .none,
        decor: AnyView? = nil,
        accessibilityLabel: String = "按钮",
        action: @escaping () -> Void
    ) {
        let validSize = size.isFinite ? max(1, size) : 40
        self.icon = icon
        self.color = color
        self.size = CGSize(width: validSize, height: validSize)
        self.shape = shape ?? AnyShape(RoundedRectSmoothed(cornerRadius: validSize / 2))
        self.texture = texture
        self.border = border
        self.decor = decor
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    /// Create a button with an explicitly sized hit target, including non-square shapes.
    public init(
        icon: AnyView,
        buttonSize: CGSize,
        color: Color = .primary,
        shape: AnyShape? = nil,
        texture: CapsuleButtonTexture = .color(Color.primary.opacity(0.07)),
        border: CapsuleButtonBorder = .none,
        decor: AnyView? = nil,
        accessibilityLabel: String = "按钮",
        action: @escaping () -> Void
    ) {
        let width = buttonSize.width.isFinite ? max(1, buttonSize.width) : 40
        let height = buttonSize.height.isFinite ? max(1, buttonSize.height) : 40
        self.icon = icon
        self.color = color
        self.size = CGSize(width: width, height: height)
        self.shape = shape ?? AnyShape(RoundedRectSmoothed(cornerRadius: min(width, height) / 2))
        self.texture = texture
        self.border = border
        self.decor = decor
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    /// Convenience initializer for Apple's SF Symbols.
    public init(
        systemName: String,
        color: Color = .primary,
        size: CGFloat = 40,
        iconSize: CGFloat = 17,
        shape: AnyShape? = nil,
        texture: CapsuleButtonTexture = .color(Color.primary.opacity(0.07)),
        border: CapsuleButtonBorder = .none,
        decor: AnyView? = nil,
        accessibilityLabel: String = "按钮",
        action: @escaping () -> Void
    ) {
        self.init(
            icon: AnyView(Image(systemName: systemName).font(.system(size: max(1, iconSize)))),
            color: color,
            size: size,
            shape: shape,
            texture: texture,
            border: border,
            decor: decor,
            accessibilityLabel: accessibilityLabel,
            action: action
        )
    }

    /// Convenience initializer for emoji or other text glyphs.
    public init(
        emoji: String,
        color: Color = .primary,
        size: CGFloat = 40,
        fontSize: CGFloat = 19,
        shape: AnyShape? = nil,
        texture: CapsuleButtonTexture = .color(Color.primary.opacity(0.07)),
        border: CapsuleButtonBorder = .none,
        decor: AnyView? = nil,
        accessibilityLabel: String = "按钮",
        action: @escaping () -> Void
    ) {
        self.init(
            icon: AnyView(Text(emoji).font(.system(size: max(1, fontSize)))),
            color: color,
            size: size,
            shape: shape,
            texture: texture,
            border: border,
            decor: decor,
            accessibilityLabel: accessibilityLabel,
            action: action
        )
    }

    public var body: some View {
        CapsuleButton(
            content: AnyView(icon
                .frame(width: size.width, height: size.height)
                .foregroundStyle(color)),
            shape: shape,
            texture: texture,
            border: border,
            foreground: color,
            padding: EdgeInsets(),
            decor: decor,
            action: action
        )
        .frame(width: size.width, height: size.height)
        .contentShape(shape)
        .accessibilityLabel(accessibilityLabel)
    }
}
