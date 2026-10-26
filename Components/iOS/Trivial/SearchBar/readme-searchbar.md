# SearchBar 组件设计需求

## 目标与边界

实现一个可跨页面、跨项目复用的 SwiftUI 搜索栏。搜索栏由三个视觉/交互部分组成：底层胶囊容器、文本输入区域、搜索按钮。组件负责布局与外观组合；搜索逻辑、数据过滤、导航和结果呈现仍由调用方负责。

优先复用项目现有基础组件，不在 SearchBar 内重新实现一套 Shape、虚线边框或输入框绘制逻辑：

- 胶囊容器复用 Capsules 组件中已经抽象出的 Shape / Texture / Border 思路。
- 虚线描边复用 `DashedPath` 与 `DashedLineConfiguration`。
- 输入行为参考 `TextFieldCustom`，但 SearchBar 应能把自己的 Shape、背景和边框传给输入区域，而不是被固定的 `TextFieldCustom.ShapeStyle` 限制。
- 搜索按钮是独立的交互区域，有自己的图标、前景色、背景色、边框与点击回调；按钮绘制调用 `ButtonCustom`，不在 SearchBar 内重复实现按钮的背景与描边。

## 结构与绘制层级

最底层是胶囊容器，文本输入和搜索按钮在其内部横向排列。容器形状、输入区域形状、按钮形状可以分别配置；默认可以使用相同形状，但不能强制三者必须一致。

从底到顶的视觉关系：

1. **Capsule Texture**：容器底材，支持纯色、SwiftUI Material，以及通过自定义 View 接入项目的 Liquid Glass。
2. **Capsule Border**：沿容器 Shape 绘制，可为无边框、普通描边或 `DashedPath` 虚线。
3. **TextField**：输入文字、placeholder 及文字排版。
4. **Search Button**：独立按钮，位于输入区域末端，拥有自己的 Shape、背景、图标和边框。按钮背景不应意外覆盖整个容器边框。

布局容器（例如 `HStack`）只负责水平排列，不应代替外部的视觉层级管理。所有背景和描边都应按各自的 Shape 绘制，避免通过固定 `cornerRadius` 假设形状一定是标准圆角矩形。

## 1. Capsule 容器配置

- `shape`：接收外部构造的 `AnyShape` 或等价泛型 Shape，支持 `RoundedRectSmoothed` 等项目自定义 Shape。不要只提供 `cornerRadius: CGFloat` 这种受限接口。
- `texture`：支持项目自定义 Liquid Glass，也支持普通颜色、Material 或自定义 SwiftUI View。Texture 必须被容器 Shape 裁剪。
- `border`：支持无边框、实线、自定义 View 和 `DashedPath`。虚线配置至少能设置线宽、dash 长度、间距、端点圆角以及闭合路径的分布策略。
- 容器应填充 SearchBar 可用宽度，但不要在基础 Capsule 视觉层里写死 SearchBar 的宽度或高度。
- 容器只负责背景、轮廓和内容承载，不负责输入状态或触发搜索。

## 2. Search Button 配置

- `icon`：默认使用系统 `magnifyingglass`，允许调用方替换为任意 SwiftUI View，以便后续支持自定义图标或动画。
- `iconColor`：独立控制图标颜色。
- `buttonColor` / `buttonTexture`：控制按钮自身的底色或材质；需要支持透明背景，以便按钮融入外层胶囊。
- `buttonShape`：接收外部 Shape，支持自定义形状。
- `buttonBorder`：支持无边框、实线、`DashedPath` 虚线和自定义 View；不要假设按钮描边一定是普通 `stroke`。
- `buttonSize` 或等价的尺寸配置：控制按钮的可点击区域。可点击区域应明显大于单纯图标，且不应因图标本身的 intrinsic size 而缩小。
- `action`：点击按钮时调用。按钮应有明确的无障碍标签（默认可用“搜索”），且描边/装饰 View 不应拦截点击。
- 是否在提交键触发搜索应通过 `onSubmit` 配置，与按钮点击调用同一个或由调用方分别指定的回调，避免内部隐式执行搜索逻辑。

## 3. TextField / Placeholder 配置

- `text`：使用 `Binding<String>`，由调用方持有和管理查询文本。
- `placeholder`：空文本时显示的提示语。
- `font` / `fontSize`：支持字体配置。若同时提供 `Font` 与字号参数，应明确优先级；优先推荐直接暴露 `Font`，避免重复配置产生冲突。
- `textColor`：输入文字颜色。
- `placeholderColor`：提示文字颜色，不能简单依赖输入文字颜色，以免主题对比度不足。
- `textFieldShape`：允许接收自定义 Shape。默认可以与外层 Capsule 一致，但必须允许单独设置。
- `textFieldBackground` / `textFieldTexture`：可选。默认透明，使底层容器的 Texture 透出；如果指定背景，也必须按 `textFieldShape` 裁剪。
- `textFieldBorder`：可选，支持普通描边、自定义 View 和 `DashedPath`。默认不应重复绘制外层容器边框。
- `submitLabel`：默认 `.search`。
- `onSubmit`：键盘提交时回调。
- 输入框应自然扩展占据按钮以外的剩余宽度，并允许正常编辑、选择、复制、清空和系统键盘交互；不能将输入区域实现成只显示文本的静态 View。
- 搜索栏不应默认强制大小写转换或自动纠错。若保留这类行为控制，应由调用方显式配置。

## 4. 布局与交互规则

- 默认水平布局：`TextField` 占据剩余空间，Search Button 保持稳定的可点击尺寸。
- `spacing`、内边距、整体高度应可配置；默认值应适合常规 iOS 搜索栏，不使用固定屏幕宽度。
- 外层 Capsule 的 Shape 决定容器裁剪和边框轮廓；输入框和按钮使用各自的 Shape。三者几何参数必须独立，不能让按钮圆角参数意外改变整个容器。
- 纯装饰层必须 `.allowsHitTesting(false)`，避免挡住输入或按钮点击。
- 明确处理焦点：组件可以通过可选的 FocusState 绑定或 `focus` API 允许调用方控制焦点，但不能擅自抢焦点或在每次重绘时清除焦点。
- 搜索按钮点击与键盘提交都应通过明确的 callback 暴露。是否清空、节流、防抖、过滤数据、展示结果由调用方决定。
- 为输入框和按钮提供稳定的 accessibility label；布局和颜色变化不能破坏系统可访问性。

## 建议的公开 API 形态

实现时优先使用有语义的配置类型，避免 SearchBar 初始化器变成大量相互关联的散装参数。例如：

- `SearchBar`：组合容器、输入框和搜索按钮。
- `SearchBarCapsuleStyle`：容器 Shape、Texture、Border、padding 与高度。
- `SearchBarFieldStyle`：输入区域 Shape、文字/placeholder 样式、可选背景与描边。
- `SearchBarButtonStyle`：图标、图标颜色、按钮 Texture、Shape、Border、点击区域尺寸。
- `SearchBar` 的必需行为参数：`text: Binding<String>`、`placeholder`、`onSearch`；`onSubmit` 可默认复用 `onSearch`，但该行为必须在文档中明确。

以上是职责边界，不要求必须照搬这些类型名称。如果最终实现选择更轻量的 API，也必须保持三部分配置互不混淆，并能表达所有上述视觉能力。

## 与现有组件的关系

- SearchBar 内的搜索按钮调用 `ButtonCustom`；`ButtonCustom` 复用 `CapsuleButton` 的 Shape、Texture、Border 设计原则。但不要把整个 SearchBar 做成一个 `Button`：输入框必须可编辑，按钮只是其中一部分。
- 复用 `DashedPath` 的实际 API 与 `DashedLineConfiguration`，不要另写一套虚线算法。
- 可参考 `TextFieldCustom` 的 Binding、placeholder、字体和提交标签，但应避免它当前有限的 Shape 枚举阻碍任意 Shape 支持。若扩展 `TextFieldCustom`，要检查并保留现有调用点的行为兼容性。
- 不在本组件中实现搜索结果列表、数据源、筛选规则、网络请求或导航。

## 验收标准

- 外层容器、输入框、搜索按钮可独立配置 Shape 和 Border。
- 外层 Texture 可使用自定义 View，包括项目的 Liquid Glass，并被外层 Shape 正确裁剪。
- 容器、输入框和按钮描边均能使用 `DashedPath`，且虚线配置由调用方控制。
- 输入框是真实可编辑的 `TextField`，支持绑定、placeholder、文字样式和提交回调。
- 按钮支持独立图标、图标颜色、按钮颜色/材质、边框和点击回调。
- 输入区域自动占据剩余宽度，按钮保持可用的点击面积。
- Decor 和边框不拦截输入、点击或焦点交互。
- 不把拟态水滴等未确定的装饰预设混入 SearchBar 的基础 API；预设可在基础组件稳定后另行添加。
