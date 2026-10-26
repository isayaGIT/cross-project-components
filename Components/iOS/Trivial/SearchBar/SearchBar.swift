import SwiftUI
import LineDashed

/// The surface rendered inside a SearchBar, field, or search button shape.
public enum SearchBarTexture {
    case clear
    case material(Material = .ultraThin)
    case color(Color)
    case custom(AnyView)
}

/// A shape-following border. Dashed borders are rendered by the shared DashedPath component.
public enum SearchBarBorder {
    case none
    case solid(color: Color, lineWidth: CGFloat = 1)
    case dashed(
        configuration: DashedLineConfiguration = .init(lineWidth: 2.5, dashLength: 8, dashSpacing: 4),
        color: Color,
        fillCoordinates: DashedLineFillCoordinates = .pathContinuous,
        phase: CGFloat = 0
    )
    case custom(AnyView)
}

/// Visual and layout configuration for the outer SearchBar capsule.
public struct SearchBarCapsuleStyle {
    public var shape: AnyShape
    public var texture: SearchBarTexture
    public var border: SearchBarBorder
    public var contentInsets: EdgeInsets
    public var minHeight: CGFloat
    public var decor: AnyView?

    public init(
        shape: AnyShape = AnyShape(Capsule()),
        texture: SearchBarTexture = .color(Color(uiColor: .tertiarySystemFill)),
        border: SearchBarBorder = .none,
        contentInsets: EdgeInsets = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 8),
        minHeight: CGFloat = 36,
        decor: AnyView? = nil
    ) {
        self.shape = shape
        self.texture = texture
        self.border = border
        self.contentInsets = contentInsets
        self.minHeight = max(0, minHeight.isFinite ? minHeight : 48)
        self.decor = decor
    }
}

/// Typography and optional independent surface for the editable text field.
public struct SearchBarFieldStyle {
    public var shape: AnyShape
    public var font: Font
    public var textColor: Color
    public var placeholderColor: Color
    public var texture: SearchBarTexture?
    public var border: SearchBarBorder
    public var horizontalPadding: CGFloat
    public var autocapitalization: TextInputAutocapitalization
    public var autocorrectionDisabled: Bool

    public init(
        shape: AnyShape = AnyShape(Capsule()),
        font: Font = .system(size: 14),
        textColor: Color = .primary,
        placeholderColor: Color = .secondary,
        texture: SearchBarTexture? = nil,
        border: SearchBarBorder = .none,
        horizontalPadding: CGFloat = 8,
        autocapitalization: TextInputAutocapitalization = .never,
        autocorrectionDisabled: Bool = true
    ) {
        self.shape = shape
        self.font = font
        self.textColor = textColor
        self.placeholderColor = placeholderColor
        self.texture = texture
        self.border = border
        self.horizontalPadding = max(0, horizontalPadding.isFinite ? horizontalPadding : 8)
        self.autocapitalization = autocapitalization
        self.autocorrectionDisabled = autocorrectionDisabled
    }
}

/// Appearance and hit-target configuration for the search action button.
public struct SearchBarButtonStyle {
    public var icon: AnyView
    public var iconColor: Color
    public var shape: AnyShape
    public var texture: SearchBarTexture
    public var border: SearchBarBorder
    public var size: CGSize
    public var accessibilityLabel: String

    public init(
        icon: AnyView = AnyView(Image(systemName: "magnifyingglass").font(.system(size: 18, weight: .medium))),
        iconColor: Color = .secondary,
        shape: AnyShape = AnyShape(Circle()),
        texture: SearchBarTexture = .clear,
        border: SearchBarBorder = .none,
        size: CGSize = CGSize(width: 36, height: 36),
        accessibilityLabel: String = "搜索"
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.shape = shape
        self.texture = texture
        self.border = border
        self.size = CGSize(
            width: max(1, size.width.isFinite ? size.width : 36),
            height: max(1, size.height.isFinite ? size.height : 36)
        )
        self.accessibilityLabel = accessibilityLabel
    }
}

/// A reusable search field composed of an outer surface, an editable TextField, and an independent button.
/// Search behavior belongs to the caller; both button taps and keyboard submission call `onSearch` by default.
public struct SearchBar: View {
    @Binding private var text: String
    private let placeholder: String
    private let capsuleStyle: SearchBarCapsuleStyle
    private let fieldStyle: SearchBarFieldStyle
    private let buttonStyle: SearchBarButtonStyle
    private let leadingContent: AnyView?
    private let trailingContent: AnyView?
    private let showsSearchButton: Bool
    private let spacing: CGFloat
    private let submitLabel: SubmitLabel
    private let focus: FocusState<Bool>.Binding?
    private let onSearch: () -> Void
    private let onSubmit: (() -> Void)?

    @FocusState private var internalFocus: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "搜索",
        capsuleStyle: SearchBarCapsuleStyle = .init(),
        fieldStyle: SearchBarFieldStyle = .init(),
        buttonStyle: SearchBarButtonStyle = .init(),
        leadingContent: AnyView? = nil,
        trailingContent: AnyView? = nil,
        showsSearchButton: Bool = true,
        spacing: CGFloat = 6,
        submitLabel: SubmitLabel = .search,
        focus: FocusState<Bool>.Binding? = nil,
        onSearch: @escaping () -> Void = {},
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.capsuleStyle = capsuleStyle
        self.fieldStyle = fieldStyle
        self.buttonStyle = buttonStyle
        self.leadingContent = leadingContent
        self.trailingContent = trailingContent
        self.showsSearchButton = showsSearchButton
        self.spacing = max(0, spacing.isFinite ? spacing : 6)
        self.submitLabel = submitLabel
        self.focus = focus
        self.onSearch = onSearch
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: spacing) {
            if let leadingContent {
                leadingContent
            }

            editableField
                .frame(maxWidth: .infinity, minHeight: capsuleStyle.minHeight)

            if showsSearchButton {
                ButtonCustom(
                    icon: buttonStyle.icon,
                    buttonSize: buttonStyle.size,
                    color: buttonStyle.iconColor,
                    shape: buttonStyle.shape,
                    texture: capsuleTexture(from: buttonStyle.texture),
                    border: capsuleBorder(from: buttonStyle.border, shape: buttonStyle.shape),
                    accessibilityLabel: buttonStyle.accessibilityLabel,
                    action: onSearch
                )
                .frame(width: buttonStyle.size.width, height: buttonStyle.size.height)
            }

            if let trailingContent {
                trailingContent
            }
        }
        .padding(capsuleStyle.contentInsets)
        .frame(minHeight: capsuleStyle.minHeight)
        .background {
            textureView(capsuleStyle.texture)
                .clipShape(capsuleStyle.shape)
        }
        .overlay {
            borderView(capsuleStyle.border, shape: capsuleStyle.shape)
                .allowsHitTesting(false)
        }
        .overlay {
            if let decor = capsuleStyle.decor {
                decor.allowsHitTesting(false)
            }
        }
        .contentShape(capsuleStyle.shape)
    }

    @ViewBuilder
    private var editableField: some View {
        let field = TextField(
            "",
            text: $text,
            prompt: Text(placeholder).foregroundColor(fieldStyle.placeholderColor)
        )
        .font(fieldStyle.font)
        .foregroundStyle(fieldStyle.textColor)
        .textInputAutocapitalization(fieldStyle.autocapitalization)
        .autocorrectionDisabled(fieldStyle.autocorrectionDisabled)
        .submitLabel(submitLabel)
        .onSubmit { (onSubmit ?? onSearch)() }
        .padding(.horizontal, fieldStyle.horizontalPadding)
        .frame(maxWidth: .infinity, minHeight: capsuleStyle.minHeight)
        .background {
            if let texture = fieldStyle.texture {
                textureView(texture).clipShape(fieldStyle.shape)
            }
        }
        .overlay {
            borderView(fieldStyle.border, shape: fieldStyle.shape)
                .allowsHitTesting(false)
        }

        if let focus {
            field.focused(focus)
        } else {
            field.focused($internalFocus)
        }
    }

    private func capsuleTexture(from texture: SearchBarTexture) -> CapsuleButtonTexture {
        switch texture {
        case .clear:
            return .color(.clear)
        case .material(let material):
            return .material(material)
        case .color(let color):
            return .color(color)
        case .custom(let view):
            return .custom(view)
        }
    }

    private func capsuleBorder(from border: SearchBarBorder, shape: AnyShape) -> CapsuleButtonBorder {
        switch border {
        case .none:
            return .none
        case .solid(let color, let lineWidth):
            return .solid(color: color, lineWidth: lineWidth)
        case .dashed(let configuration, let color, let fillCoordinates, let phase):
            return .custom(AnyView(GeometryReader { geometry in
                DashedPath(
                    path: shapePath(for: geometry.size, shape: shape),
                    configuration: configuration,
                    fill: .color(color),
                    fillCoordinates: fillCoordinates,
                    phase: phase
                )
            }))
        case .custom(let view):
            return .custom(view)
        }
    }

    private func shapePath(for size: CGSize, shape: AnyShape) -> Path {
        shape.path(in: CGRect(origin: .zero, size: size))
    }

    @ViewBuilder
    private func textureView(_ texture: SearchBarTexture) -> some View {
        switch texture {
        case .clear:
            Color.clear
        case .material(let material):
            Rectangle().fill(material)
        case .color(let color):
            color
        case .custom(let view):
            view
        }
    }

    @ViewBuilder
    private func borderView(_ border: SearchBarBorder, shape: AnyShape) -> some View {
        switch border {
        case .none:
            EmptyView()
        case .solid(let color, let lineWidth):
            shape.stroke(color, lineWidth: lineWidth.isFinite ? max(0, lineWidth) : 0)
        case .dashed(let configuration, let color, let fillCoordinates, let phase):
            GeometryReader { geometry in
                DashedPath(
                    path: shape.path(in: CGRect(origin: .zero, size: geometry.size)),
                    configuration: configuration,
                    fill: .color(color),
                    fillCoordinates: fillCoordinates,
                    phase: phase
                )
            }
        case .custom(let view):
            view
        }
    }
}
