# CharacterStatus

Shared status states for a user or character: `online`, `offline`, `replying`, and `error`. Each state provides its documented Chinese label and semantic color. The view supports custom title, color, font family, font size, and an optional indicator dot.

```swift
CharacterStatus(.replying, title: "正在输入...", color: .yellow, fontSize: 12)
```

For `.replying` and `.error`, an optional `onAction` callback can hand off to a host-owned stream inspector or error-details view. Streaming telemetry and rich error details themselves remain separate host-owned components; this label does not simulate LLM transport state.
