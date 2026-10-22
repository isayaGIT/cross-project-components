# InputBar

A standalone, native SwiftUI message composer inspired by the interaction model of [assistant-ui](https://github.com/assistant-ui/assistant-ui). It has no web view, third-party dependency, or network client.

## Responsibilities

- Owns presentation and local view interaction only.
- Reads and edits the draft through `Binding<String>`.
- Receives generation state from the caller and reports send/stop actions through closures.
- Shows attachment and tools controls only when their callbacks are supplied.
- Uses adaptive SwiftUI system colors and material, so it follows light/dark appearance without a second design-token system.

It deliberately does **not** clear the draft, manage requests, store conversation history, or decide what attachment/tools actions do. The parent owns those behaviors.

## Usage

```swift
struct ChatScreen: View {
    @State private var draft = ""
    @State private var isGenerating = false

    var body: some View {
        InputBar(
            text: $draft,
            placeholder: "Message",
            isGenerating: isGenerating,
            onSend: sendDraft,
            onStop: stopGeneration,
            onAttach: chooseAttachment,
            onTools: showTools
        )
        .padding()
    }

    private func sendDraft() {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        // Pass `message` to the app's own conversation layer.
        draft = ""
        isGenerating = true
    }

    private func stopGeneration() {
        // Cancel the app's active generation task.
        isGenerating = false
    }

    private func chooseAttachment() { /* Present the app's attachment picker. */ }
    private func showTools() { /* Present the app's tools menu. */ }
}
```

Import the existing Swift package product:

```swift
import CrossProjectComponentsIOS
```

`InputBar` requires iOS 17 or later, matching the package's current deployment target.

## Public API

| Input | Responsibility |
| --- | --- |
| `text` | Caller-owned draft, editable through a binding |
| `placeholder` | Placeholder text; defaults to `Message` |
| `isGenerating` | Caller-owned generation state; swaps send for stop |
| `maxLines` | Visible text-line limit; defaults to 6 and is clamped to at least 1 |
| `onSend` | Invoked only for a non-whitespace draft when not generating |
| `onStop` | Optional cancellation callback; stop is disabled if absent |
| `onAttach` | Optional attachment action; control is omitted if absent |
| `onTools` | Optional tools-menu action; control is omitted if absent |

The component is intentionally kept in one source file: its layout and event flow are small enough that splitting them into internal types would add navigation without establishing a reusable abstraction.

## Emoji picker

When the draft is empty, the trailing action opens the reusable `StickerKeyboard`; when the draft contains non-whitespace text, the trailing action is Send. While the emoji panel is open, the trailing control switches to the system-keyboard button. Selecting an emoji appends it to the bound draft. The picker itself does not own the draft or text-field focus.

`InputBar` exposes `stickerKeyboardConfiguration` so the host can configure the panel's preferred height and grid columns without depending on its implementation. The default height is available as `StickerKeyboard.defaultHeight`. Place `InputBar` in a bottom `safeAreaInset` (as in the demo) so SwiftUI accounts for the expanded panel height and moves the composer/content above it automatically.

```swift
.safeAreaInset(edge: .bottom, spacing: 0) {
    InputBar(
        text: $draft,
        stickerKeyboardConfiguration: .init(height: 280, columns: 8),
        onSend: sendMessage
    )
}
```
