# ListApiConfig

`ListApiConfig` is a minimal SwiftUI container for composing existing `ListNode` rows vertically. It does not reimplement row UI, manage provider data, or handle navigation, API keys, validation, or persistence.

## Example

```swift
ListApiConfig(spacing: 0) {
    ListNodeLlmProviders(
        icon: Image(systemName: "sparkles"),
        title: "OpenAI",
        subtitle: "API Key 已配置",
        status: .ready,
        onTap: { /* host handles configuration */ }
    )

    Divider().padding(.leading, 16)

    ListNodeLlmProviders(
        icon: Image(systemName: "brain.head.profile"),
        title: "Anthropic",
        subtitle: "尚未添加 API Key",
        status: .unavailable,
        onTap: { /* host handles configuration */ }
    )
}
```

Pass any existing `ListNode` rows in the builder. The container only controls vertical arrangement and spacing; wrap it in your own outer view to provide a background, heading, or other page-level layout.
