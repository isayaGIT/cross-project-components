import SwiftUI

/// The placement of a banner's action buttons.
public enum BannerActionLayout: Equatable {
    /// Actions are stacked vertically at the trailing edge. This is the default.
    case vertical
    /// Actions are arranged horizontally at the trailing edge.
    case horizontal
    /// Actions are arranged horizontally below the banner content.
    case bottom
}

/// A single action displayed by a `Banner`.
public struct BannerAction {
    public let title: String
    public let systemImage: String?
    public let role: ButtonRole?
    private let handler: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.handler = action
    }

    fileprivate func perform() {
        handler()
    }
}

/// A compact, reusable notice with optional leading icon and up to two actions.
///
/// The message determines the banner's height. The host owns presentation and
/// dismissal; action handlers are invoked only when their corresponding button is tapped.
public struct Banner: View {
    private let text: String
    private let icon: Image?
    private let iconColor: Color?
    private let iconSize: CGFloat
    private let textFont: Font
    private let textFontSize: CGFloat?
    private let actionFont: Font
    private let actions: [BannerAction]
    private let actionLayout: BannerActionLayout
    private let background: Color
    private let foreground: Color
    private let borderColor: Color
    private let borderWidth: CGFloat
    private let cornerRadius: CGFloat
    private let contentPadding: EdgeInsets

    public init(
        text: String,
        icon: Image? = nil,
        iconColor: Color? = nil,
        iconSize: CGFloat = 18,
        textFont: Font = .body,
        textFontSize: CGFloat? = nil,
        actionFont: Font = .system(size: 13, weight: .medium),
        actions: [BannerAction] = [],
        actionLayout: BannerActionLayout = .vertical,
        background: Color = Color.primary.opacity(0.045),
        foreground: Color = .primary,
        borderColor: Color = Color.primary.opacity(0.14),
        borderWidth: CGFloat = 1,
        cornerRadius: CGFloat = 12,
        contentPadding: EdgeInsets = EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
    ) {
        precondition(actions.count <= 2, "Banner supports at most two actions.")
        self.text = text
        self.icon = icon
        self.iconColor = iconColor
        self.iconSize = max(0, iconSize)
        self.textFont = textFont
        self.textFontSize = textFontSize.map { max(1, $0) }
        self.actionFont = actionFont
        self.actions = actions
        self.actionLayout = actionLayout
        self.background = background
        self.foreground = foreground
        self.borderColor = borderColor
        self.borderWidth = max(0, borderWidth)
        self.cornerRadius = max(0, cornerRadius)
        self.contentPadding = contentPadding
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if actionLayout == .bottom {
                content
                if !actions.isEmpty {
                    actionRow
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !actions.isEmpty {
                        actionRow
                    }
                }
            }
        }
        .padding(contentPadding)
        .background(
            background,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        }
        .foregroundStyle(foreground)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 10) {
            if let icon {
                icon
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(iconColor ?? foreground)
                    .frame(width: 22, alignment: .center)
                    .accessibilityHidden(true)
            }

            Text(text)
                .font(textFontSize.map { .system(size: $0) } ?? textFont)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        switch actionLayout {
        case .vertical:
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                    actionButton(action)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        case .horizontal, .bottom:
            HStack(spacing: 8) {
                ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                    actionButton(action)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func actionButton(_ action: BannerAction) -> some View {
        Button(role: action.role) {
            action.perform()
        } label: {
            HStack(spacing: 5) {
                if let systemImage = action.systemImage {
                    Image(systemName: systemImage)
                }
                Text(action.title)
                    .fixedSize()
            }
            .font(actionFont)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
    }
}
