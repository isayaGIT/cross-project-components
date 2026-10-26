# ButtonCustom

`ButtonCustom` 是一个以图标为内容的通用 SwiftUI 按钮，视觉层复用 `CapsuleButton` 的 Shape、Texture、Border 和 decor 绘制逻辑。它适用于工具栏、搜索栏、操作入口等图标按钮，不承担业务动作以外的状态管理。

## 图标传入方式

- SF Symbols：使用 `ButtonCustom(systemName: "magnifyingglass", ...)`。
- Emoji / 文字符号：使用 `ButtonCustom(emoji: "🔍", ...)`。
- 任意 SwiftUI 图标：使用 `ButtonCustom(icon: AnyView(customIcon), ...)`。自定义 View 可包含项目自己的 HTML 图标渲染结果。

## 示例

```swift
ButtonCustom(
    systemName: "magnifyingglass",
    color: .primary,
    size: 40,
    iconSize: 17,
    texture: .color(.clear),
    border: .none,
    accessibilityLabel: "搜索",
    action: performSearch
)
```

## 外观与几何

- `color` 控制图标前景色。
- `size` 控制正方形按钮尺寸，单位为 point；`iconSize` / `fontSize` 控制 SF Symbol 或 Emoji 的字号。
- 默认 Shape 是 `RoundedRectSmoothed(cornerRadius: size / 2)`，正方形按钮因此呈现为平滑的纯圆形。可通过 `shape` 传入任意 `AnyShape` 覆盖。
- `texture` 支持 `CapsuleButtonTexture.material`、`.color`、`.custom`；`border` 支持 `CapsuleButtonBorder.none`、`.solid`、`.dashed`、`.custom`。
- `decor` 可传入不参与 hit-testing 的装饰 View。
- `accessibilityLabel` 设置无障碍标签；`action` 是按钮点击回调。

底层 `CapsuleButton` 保留原有字符串初始化器，现有文本胶囊按钮的调用方式不变。图标按钮通过内容初始化器复用相同绘制层，而不是在每个使用点重新绘制背景与边框。
