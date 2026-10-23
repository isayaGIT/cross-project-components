# ConfigSheet

ConfigSheet is a reusable visual shell for configuration screens. It standardizes title typography/alignment, spacing, padding, background, two text groups, two icon groups, and optional custom path/divider views. The content layout remains free-form SwiftUI, so list-based, form-based, and bespoke settings can share the same visual language without being forced into one schema.

ConfigSheet does **not** present or dismiss a sheet and does not own configuration state or persistence. Put it inside BottomSheet or another host container.

## Basic usage

```swift
let style = ConfigSheetStyle(
    titleColor: .primary,
    textGroup1Color: .primary,
    textGroup2Color: .secondary
)

ConfigSheet(
    title: "API 配置",
    style: style,
    pathGroup1: { Divider() },
    pathGroup2: { Divider() }
) {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            ConfigSheetIcon(Image(systemName: "key.fill"), style: style)
            VStack(alignment: .leading, spacing: 4) {
                ConfigSheetText("API Key", group: .primary, style: style)
                ConfigSheetText("用于连接模型服务", group: .secondary, style: style)
            }
        }

        TextField("粘贴 API Key", text: $apiKey)
    }
}
```

## Design boundary

- ConfigSheetStyle: shared visual tokens for title, text groups, icon groups, background, spacing, and padding.
- ConfigSheet: shared shell and optional custom path/divider slots.
- ConfigSheetText / ConfigSheetIcon: reusable styling helpers.
- The caller owns fields, row arrangement, validation, state, persistence, and sheet presentation.
- Custom layouts can still use native SwiftUI views; no fixed JSON/schema is required.

