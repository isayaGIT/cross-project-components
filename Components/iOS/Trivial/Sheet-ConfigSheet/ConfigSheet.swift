import SwiftUI

/// Shared visual language for settings/configuration screens.
///
/// ConfigSheet intentionally does not own presentation, persistence, or field layout.
/// Use it inside any host container (including BottomSheet), and compose the content
/// from native SwiftUI views or the reusable text/icon helpers below.
public struct ConfigSheetStyle {
    public var titleFont: Font?
    public var titleFontSize: CGFloat
    public var titleColor: Color
    public var titleAlignment: TextAlignment

    public var textGroup1Font: Font?
    public var textGroup1FontSize: CGFloat
    public var textGroup1Color: Color

    public var textGroup2Font: Font?
    public var textGroup2FontSize: CGFloat
    public var textGroup2Color: Color

    public var iconGroup1FontSize: CGFloat
    public var iconGroup1Color: Color

    public var iconGroup2FontSize: CGFloat
    public var iconGroup2Color: Color

    public var backgroundColor: Color
    public var contentSpacing: CGFloat
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat

    public init(
        titleFont: Font? = nil,
        titleFontSize: CGFloat = 22,
        titleColor: Color = .primary,
        titleAlignment: TextAlignment = .leading,
        textGroup1Font: Font? = nil,
        textGroup1FontSize: CGFloat = 16,
        textGroup1Color: Color = .primary,
        textGroup2Font: Font? = nil,
        textGroup2FontSize: CGFloat = 13,
        textGroup2Color: Color = .secondary,
        iconGroup1FontSize: CGFloat = 20,
        iconGroup1Color: Color = .primary,
        iconGroup2FontSize: CGFloat = 15,
        iconGroup2Color: Color = .secondary,
        backgroundColor: Color = .clear,
        contentSpacing: CGFloat = 16,
        horizontalPadding: CGFloat = 20,
        verticalPadding: CGFloat = 16
    ) {
        self.titleFont = titleFont
        self.titleFontSize = Self.validSize(titleFontSize, fallback: 22)
        self.titleColor = titleColor
        self.titleAlignment = titleAlignment
        self.textGroup1Font = textGroup1Font
        self.textGroup1FontSize = Self.validSize(textGroup1FontSize, fallback: 16)
        self.textGroup1Color = textGroup1Color
        self.textGroup2Font = textGroup2Font
        self.textGroup2FontSize = Self.validSize(textGroup2FontSize, fallback: 13)
        self.textGroup2Color = textGroup2Color
        self.iconGroup1FontSize = Self.validSize(iconGroup1FontSize, fallback: 20)
        self.iconGroup1Color = iconGroup1Color
        self.iconGroup2FontSize = Self.validSize(iconGroup2FontSize, fallback: 15)
        self.iconGroup2Color = iconGroup2Color
        self.backgroundColor = backgroundColor
        self.contentSpacing = Self.validSize(contentSpacing, fallback: 16)
        self.horizontalPadding = Self.validSize(horizontalPadding, fallback: 20)
        self.verticalPadding = Self.validSize(verticalPadding, fallback: 16)
    }

    private static func validSize(_ value: CGFloat, fallback: CGFloat) -> CGFloat {
        value.isFinite ? max(0, value) : fallback
    }
}

/// A consistent configuration-screen shell. The host controls how this view is presented.
public struct ConfigSheet<Content: View>: View {
    private let title: String?
    private let style: ConfigSheetStyle
    private let pathGroup1: AnyView
    private let pathGroup2: AnyView
    private let content: Content

    public init(
        title: String? = nil,
        style: ConfigSheetStyle = .init(),
        @ViewBuilder pathGroup1: () -> some View = { EmptyView() },
        @ViewBuilder pathGroup2: () -> some View = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.style = style
        self.pathGroup1 = AnyView(pathGroup1())
        self.pathGroup2 = AnyView(pathGroup2())
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: style.contentSpacing) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(style.titleFont ?? .system(size: style.titleFontSize, weight: .semibold))
                    .foregroundStyle(style.titleColor)
                    .multilineTextAlignment(style.titleAlignment)
                    .frame(maxWidth: .infinity, alignment: style.titleAlignment == .center ? .center : (style.titleAlignment == .trailing ? .trailing : .leading))
                    .accessibilityAddTraits(.isHeader)
            }

            pathGroup1
            content
            pathGroup2
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.backgroundColor)
    }

    /// The visual tokens are exposed so custom layouts can use the same system.
    public var configurationStyle: ConfigSheetStyle { style }
}

/// Standardized text for the two common text groups used in configuration screens.
public struct ConfigSheetText: View {
    public enum Group {
        case primary
        case secondary
    }

    private let text: String
    private let group: Group
    private let style: ConfigSheetStyle
    private let alignment: TextAlignment
    private let lineLimit: Int?

    public init(
        _ text: String,
        group: Group = .primary,
        style: ConfigSheetStyle = .init(),
        alignment: TextAlignment = .leading,
        lineLimit: Int? = nil
    ) {
        self.text = text
        self.group = group
        self.style = style
        self.alignment = alignment
        self.lineLimit = lineLimit
    }

    public var body: some View {
        Text(text)
            .font(group == .primary
                  ? (style.textGroup1Font ?? .system(size: style.textGroup1FontSize, weight: .medium))
                  : (style.textGroup2Font ?? .system(size: style.textGroup2FontSize)))
            .foregroundStyle(group == .primary ? style.textGroup1Color : style.textGroup2Color)
            .multilineTextAlignment(alignment)
            .lineLimit(lineLimit)
    }
}

/// Standardized SF Symbol/image sizing and tint for the two common icon groups.
public struct ConfigSheetIcon: View {
    public enum Group {
        case primary
        case secondary
    }

    private let image: Image
    private let group: Group
    private let style: ConfigSheetStyle

    public init(_ image: Image, group: Group = .primary, style: ConfigSheetStyle = .init()) {
        self.image = image
        self.group = group
        self.style = style
    }

    public var body: some View {
        image
            .font(.system(size: group == .primary ? style.iconGroup1FontSize : style.iconGroup2FontSize))
            .foregroundStyle(group == .primary ? style.iconGroup1Color : style.iconGroup2Color)
            .accessibilityHidden(true)
    }
}

#Preview {
    ConfigSheet(
        title: "API 配置",
        pathGroup1: { Divider() },
        pathGroup2: { Divider() }
    ) {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ConfigSheetIcon(Image(systemName: "key.fill"))
                VStack(alignment: .leading, spacing: 4) {
                    ConfigSheetText("API Key", group: .primary)
                    ConfigSheetText("用于连接模型服务", group: .secondary)
                }
                Spacer()
                ConfigSheetIcon(Image(systemName: "checkmark.circle.fill"), group: .secondary)
            }

            TextField("粘贴 API Key", text: .constant(""))
                .textFieldStyle(.roundedBorder)

            HStack {
                ConfigSheetText("请求超时", group: .primary)
                Spacer()
                ConfigSheetText("30 秒", group: .secondary)
            }
        }
    }
    .padding()
}

