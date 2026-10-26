# CapsuleButton 设计需求

## 目标
构建可跨项目复用的 SwiftUI 按钮。外部可以独立配置形状与各视觉层。组件保持内容驱动的自然尺寸，不设置固定宽度。

## API 要求
- `shape`：接收外部构造好的 `AnyShape`（或等价的泛型 Shape API）。组件不再提供 `cornerRadius` 作为几何配置；由调用方决定 Shape 的构造参数，例如 `RoundedRectSmoothed` 的参数。
- `texture`：支持任意 SwiftUI View Builder，包括项目中的自定义 Liquid Glass。Texture 必须绘制在传入 Shape 的几何范围内，并由 Shape 裁剪。
- `border`：支持调用方提供自定义边框 View，并提供便捷的虚线配置，兼容 `DashedPath` / `DashedLineConfiguration`。
- `content`：默认支持文字；设计上允许未来扩展为自定义内容。
- `decor`：接收任意 SwiftUI View，位于内容之上，允许有意遮挡文字。默认使用 `allowsHitTesting(false)`，不能意外拦截按钮点击。
- 保留按钮 action、无默认按钮装饰的样式、无障碍语义和内容自适应尺寸。

## 绘制顺序
内容的 `HStack` 只负责布局，不负责整个胶囊的视觉层级。先测量和布局内容，再从底层到顶层绘制：
1. **Texture**：使用传入的 Shape 约束并裁剪材质。
2. **Border**：与同一 Shape 轮廓对齐，绘制在 Texture 上方、内容下方。
3. **Content / Text**：默认文字内容。
4. **Decor**：最顶层，可以遮挡内容。

Shape 是各层共享的几何输入，而不是一个独立的绘制层。Texture 裁剪与 Border 绘制必须使用同一个 Shape。除非调用方明确要求，否则不要将 Decor 裁剪在 Shape 内，因为装饰可能需要超出胶囊轮廓。

## 预设
1. **韩粉（`hanPink`）**：使用 `RoundedRectSmoothed`，内部采用低饱和灰粉色虚线边框，线宽要明显、略粗而不是细线；表面使用克制的浅色调。预设应当复用统一的底层配置和绘制逻辑。
2. **拟态水滴**：本轮明确暂缓，不实现。

## 兼容与迁移
- 迁移仓库中所有实际使用 `CapsuleButton` 的调用点。
- 尽可能保持原有视觉表现，但移除旧的 `cornerRadius` 初始化参数，改由调用方传入 Shape。
- 同步更新 `README.md`，说明公开 API、绘制顺序、韩粉预设及自定义 `DashedPath` 的用法。

## 验证标准
- 在当前环境支持的情况下，构建主 Swift Package 与 StickerKeyboard Demo。
- 检查所有 `CapsuleButton` 调用点，确认 Decor 默认不接收点击事件。
- 不覆盖或重置工作区中与本任务无关的既有修改。
