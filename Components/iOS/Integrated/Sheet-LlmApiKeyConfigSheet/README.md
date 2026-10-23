# SheetLlmApiKeyConfigSheet

A composed SwiftUI view for selecting an LLM provider and opening the host app's API-key configuration flow. It reuses the existing `ConfigSheet` visual shell, `ListApiConfig` vertical container, and `ListNodeLlmProviders` rows.

## Usage

```swift
let providers: [SheetLlmApiKeyConfigSheet.Provider] = [
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
    )
]

SheetLlmApiKeyConfigSheet(providers: providers) { provider in
    // Present your API-key editor for this provider.
    // Store, validate, and securely manage the key in the host application.
    print("Configure provider: \\(provider.id)")
}
```

## Responsibilities

- `ConfigSheet` provides the title and shared configuration-screen spacing/padding.
- `ListApiConfig` arranges provider rows vertically.
- `ListNodeLlmProviders` renders each provider's icon, title, subtitle, and status.
- `SheetLlmApiKeyConfigSheet` supplies provider data, dividers, and a selection callback.
- The host app owns API-key editing, secure storage, validation, network checks, and sheet presentation/dismissal.

An empty provider array displays `emptyMessage`. The component does not depend on or modify the host app's key-storage implementation.
