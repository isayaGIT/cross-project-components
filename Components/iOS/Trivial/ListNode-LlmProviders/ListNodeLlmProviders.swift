import SwiftUI

/// The configuration/health state shown for an LLM provider.
public enum ListNodeLLMProviderStatus {
    /// No API key has been configured for this provider.
    case unavailable
    /// A key is configured and the provider is considered ready by the host app.
    case ready
    /// The host app has detected a configuration or connection problem.
    case error
    /// The host app is currently checking the provider.
    case checking

    fileprivate var title: String {
        switch self {
        case .unavailable: "未配置"
        case .ready: "已就绪"
        case .error: "异常"
        case .checking: "验证中"
        }
    }

    fileprivate var color: Color {
        switch self {
        case .unavailable: .secondary
        case .ready: .green
        case .error: .red
        case .checking: .orange
        }
    }

    fileprivate var symbol: String {
        switch self {
        case .unavailable: "minus.circle"
        case .ready: "checkmark.circle.fill"
        case .error: "exclamationmark.circle.fill"
        case .checking: "arrow.triangle.2.circlepath"
        }
    }
}

/// A tappable provider row. Configuration, key storage, and verification remain host-app responsibilities.
public struct ListNodeLlmProviders: View {
    private let icon: Image
    private let title: String
    private let subtitle: String?
    private let titleFont: Font?
    private let titleFontSize: CGFloat
    private let subtitleFont: Font?
    private let subtitleFontSize: CGFloat
    private let status: ListNodeLLMProviderStatus
    private let onTap: () -> Void

    public init(
        icon: Image,
        title: String,
        subtitle: String? = nil,
        titleFont: Font? = nil,
        titleFontSize: CGFloat = 16,
        subtitleFont: Font? = nil,
        subtitleFontSize: CGFloat = 12,
        status: ListNodeLLMProviderStatus = .unavailable,
        onTap: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.titleFont = titleFont
        self.titleFontSize = titleFontSize.isFinite ? max(1, titleFontSize) : 16
        self.subtitleFont = subtitleFont
        self.subtitleFontSize = subtitleFontSize.isFinite ? max(1, subtitleFontSize) : 12
        self.status = status
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .padding(10)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(titleFont ?? .system(size: titleFontSize, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(subtitleFont ?? .system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 5) {
                    Image(systemName: status.symbol)
                        .font(.system(size: 13, weight: .medium))
                    Text(status.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(status.color)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("状态：\(status.title)")

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开 \(title) 配置")
    }
}

#Preview {
    VStack(spacing: 0) {
        ListNodeLlmProviders(
            icon: Image(systemName: "sparkles"),
            title: "OpenAI",
            subtitle: "API Key 已配置",
            status: .ready,
            onTap: {}
        )
        Divider().padding(.leading, 16)
        ListNodeLlmProviders(
            icon: Image(systemName: "brain.head.profile"),
            title: "Anthropic",
            subtitle: "尚未添加 API Key",
            status: .unavailable,
            onTap: {}
        )
        Divider().padding(.leading, 16)
        ListNodeLlmProviders(
            icon: Image(systemName: "network"),
            title: "自定义 Provider",
            subtitle: "请求失败，请检查配置",
            status: .error,
            onTap: {}
        )
    }
}
