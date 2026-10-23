# ListNodeLlmProviders

A compact, native SwiftUI list row for an LLM provider's API-key configuration status. The row displays a provider icon, name, optional helper text, status, and a disclosure indicator. Tapping the row calls the closure supplied by the host app.

```swift
ListNodeLlmProviders(
    icon: Image(systemName: "sparkles"),
    title: "OpenAI",
    subtitle: "API Key 已配置",
    status: .ready,
    onTap: { showOpenAISettings = true }
)
```

Available statuses:

- `.unavailable` — 未配置
- `.ready` — 已就绪
- `.error` — 异常
- `.checking` — 验证中

The component only renders state and forwards taps. The host app owns API-key storage, configuration UI, network requests, and status verification. Provider icons are supplied by the caller as SwiftUI `Image` values, so the component does not depend on a particular provider catalogue or asset bundle.
