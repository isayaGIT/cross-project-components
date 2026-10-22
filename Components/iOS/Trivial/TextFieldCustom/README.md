# TextFieldCustom

Reusable text input with configurable placeholder, font, foreground, background, shape, and optional border-line view.

```swift
TextFieldCustom(
    text: $query,
    placeholder: "Search stickers",
    background: AnyView(Background(color: .secondary.opacity(0.1))),
    shape: .roundedRectangle(12),
    onSubmit: { search(query) }
)
```

The component owns input styling and text entry only. Feature-specific history and search behavior stay with the calling view.
