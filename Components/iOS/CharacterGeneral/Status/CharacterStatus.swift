import SwiftUI

/// Shared status states used by user and character surfaces.
public enum CharacterStatusState: String, CaseIterable, Identifiable {
    case online
    case offline
    case replying
    case error

    public var id: String { rawValue }

    public var defaultTitle: String {
        switch self {
        case .online: "在线"
        case .offline: "离线"
        case .replying: "正在输入..."
        case .error: "出错了!"
        }
    }

    public var defaultColor: Color {
        switch self {
        case .online: .green
        case .offline: .gray
        case .replying: .yellow
        case .error: .red
        }
    }
}

/// A small, themeable status label. Detailed stream/error actions remain owned by the host.
public struct CharacterStatus: View {
    private let state: CharacterStatusState
    private let title: String?
    private let color: Color?
    private let fontName: String?
    private let fontSize: CGFloat
    private let showsIndicator: Bool
    private let onAction: (() -> Void)?

    public init(
        _ state: CharacterStatusState,
        title: String? = nil,
        color: Color? = nil,
        fontName: String? = nil,
        fontSize: CGFloat = 12,
        showsIndicator: Bool = true,
        onAction: (() -> Void)? = nil
    ) {
        self.state = state
        self.title = title
        self.color = color
        self.fontName = fontName
        self.fontSize = max(1, fontSize)
        self.showsIndicator = showsIndicator
        self.onAction = onAction
    }

    @ViewBuilder
    public var body: some View {
        if let onAction, (state == .replying || state == .error) {
            Button(action: onAction) { label }
                .buttonStyle(.plain)
                .accessibilityHint(state == .replying ? "查看回复状态" : "查看错误详情")
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: 5) {
            if showsIndicator {
                Circle().fill(color ?? state.defaultColor).frame(width: 6, height: 6)
            }
            Text(title ?? state.defaultTitle)
                .font(resolvedFont)
                .foregroundStyle(color ?? state.defaultColor)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title ?? state.defaultTitle)
    }

    private var resolvedFont: Font {
        if let fontName, !fontName.isEmpty { return .custom(fontName, size: fontSize) }
        return .system(size: fontSize, weight: .medium)
    }
}
