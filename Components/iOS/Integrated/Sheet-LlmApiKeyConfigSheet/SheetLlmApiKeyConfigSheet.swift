import SwiftUI

/// A composed provider-selection sheet for configuring LLM API keys.
///
/// This component combines `ConfigSheet`, `ListApiConfig`, and
/// `ListNodeLlmProviders`. It owns no API-key values or persistence; the host
/// application handles the selected provider's configuration flow.
public struct SheetLlmApiKeyConfigSheet: View {
    /// Data needed to display one LLM provider in the configuration list.
    public struct Provider: Identifiable {
        public let id: String
        public var title: String
        public var subtitle: String?
        public var icon: Image
        public var status: ListNodeLLMProviderStatus

        public init(
            id: String,
            title: String,
            subtitle: String? = nil,
            icon: Image,
            status: ListNodeLLMProviderStatus = .unavailable
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.status = status
        }
    }

    private let providers: [Provider]
    private let title: String
    private let style: ConfigSheetStyle
    private let emptyMessage: String
    private let onSelectProvider: (Provider) -> Void

    public init(
        providers: [Provider],
        title: String = "配置 LLM API Key",
        style: ConfigSheetStyle = .init(),
        emptyMessage: String = "暂无可配置的模型服务商",
        onSelectProvider: @escaping (Provider) -> Void
    ) {
        self.providers = providers
        self.title = title
        self.style = style
        self.emptyMessage = emptyMessage
        self.onSelectProvider = onSelectProvider
    }

    public var body: some View {
        ConfigSheet(
            title: title,
            style: style,
            pathGroup1: { Divider() }
        ) {
            if providers.isEmpty {
                Text(emptyMessage)
                    .font(style.textGroup2Font ?? .system(size: style.textGroup2FontSize))
                    .foregroundStyle(style.textGroup2Color)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .accessibilityElement(children: .combine)
            } else {
                ListApiConfig(spacing: 0) {
                    ForEach(providers) { provider in
                        ListNodeLlmProviders(
                            icon: provider.icon,
                            title: provider.title,
                            subtitle: provider.subtitle,
                            titleFont: style.textGroup1Font,
                            titleFontSize: style.textGroup1FontSize,
                            subtitleFont: style.textGroup2Font,
                            subtitleFontSize: style.textGroup2FontSize,
                            status: provider.status
                        ) {
                            onSelectProvider(provider)
                        }

                        if provider.id != providers.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }
}

#Preview("LLM API Key Config") {
    SheetLlmApiKeyConfigSheet(
        providers: [
            .init(
                id: "openai",
                title: "OpenAI",
                subtitle: "API Key 已配置",
                icon: Image(systemName: "sparkles"),
                status: .ready
            ),
            .init(
                id: "anthropic",
                title: "Anthropic",
                subtitle: "尚未添加 API Key",
                icon: Image(systemName: "brain.head.profile"),
                status: .unavailable
            ),
            .init(
                id: "custom",
                title: "自定义 Provider",
                subtitle: "检查连接配置",
                icon: Image(systemName: "network"),
                status: .error
            )
        ],
        onSelectProvider: { _ in }
    )
    .frame(maxWidth: 480)
    .padding()
}
