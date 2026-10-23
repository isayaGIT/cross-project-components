# ListNodeLlmRoute

A compact SwiftUI list row for an API/LLM routing setting. The left side shows the task icon and task name. The right side shows the provider name and model on two right-aligned lines, with the provider icon at the far right.

```swift
ListNodeLlmRoute(
    taskIcon: Image(systemName: "bubble.left.and.bubble.right"),
    taskIconColor: .blue,
    taskText: "聊天回复",
    llmIcon: Image("OpenAIIcon"),
    llmIconColor: .primary,
    llmName: "OpenAI",
    llmModelName: "GPT-5.2",
    onTap: { showRoutePicker = true }
)
```

All text, font sizes, and foreground colors can be customized independently. Supply provider artwork as an `Image` from the host app's assets or SF Symbols. `onTap` is optional: when supplied, the row becomes tappable; otherwise it is display-only. Route selection, persistence, and provider/model data remain the host app's responsibility.
