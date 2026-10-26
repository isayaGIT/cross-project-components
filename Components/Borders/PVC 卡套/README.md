# PVC 卡套（Card Holder）— 归档实现

这是一次独立保存的视觉实验：透明内容面外侧有一圈类似透明 PVC 卡套/卡牌保护壳的厚边、反射与高光，并带有投影。它不是通用的 `CardGeneral` 主组件目录，而是保留该视觉语言的完整、可独立运行的快照。

## 内容

- `CardGeneral.swift`：当时的 Metal shader、渲染器、Palette、Shape 泛型组件和阴影逻辑完整副本。
- `Sources/CardGeneralDemoApp.swift`：独立 Demo；默认选择 Pearl、浅色画布、圆角矩形，支持切换圆形/圆角矩形、六种 Palette 和深色画布。
- `project.yml` / `PVCCardHolderDemo.xcodeproj`：独立 Xcode 工程，不依赖仓库根目录的 Swift Package，也不依赖原 `CardGeneral` 源文件。只需 XcodeGen 生成/更新工程后即可构建。
- `Screenshots/Pearl-before-layer-fix.png`：修复 overlay 层级前的保存画面。
- `Screenshots/Pearl-after-layer-fix.png`：修复 overlay 层级后的保存画面（当前版本基线）。

## 运行

1. 在本目录执行 `xcodegen generate`（若已存在 `.xcodeproj`，会按 `project.yml` 重建工程）。
2. 打开 `PVCCardHolderDemo.xcodeproj`，选择 `PVCCardHolderDemo` scheme 和 iOS Simulator。
3. Build & Run。首次运行默认即为保存的 Pearl 浅色画布效果。

## 快照与维护约束

此目录是有意保留的独立快照。不要通过引用 `Components/iOS/Card-General/CardGeneral.swift` 来替代本地副本；若要修改 PVC 卡套视觉，应先复制/更新本目录并重新保存截图，避免原组件未来迭代导致归档视觉悄悄变化。

原始截图来自 iPhone 15 Plus / iOS 18.6 Simulator，1290 × 2796 PNG。Metal 渲染会随设备、OS、GPU 与帧时序产生细微差异，因此这里保存的是实现和运行条件，而非逐像素保证跨设备一致。
