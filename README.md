# 跨项目组件库 · Cross-Project Components

独立、轻量、可直接嵌入其他项目的 UI 组件。每个组件尽量不依赖宿主项目的数据模型、路由或业务层。

## 当前组件：Filmstrip Scrubber（连续拖动胶片）

![Filmstrip Scrubber — real interaction recording](Examples/filmstrip-scrubber.gif)

上方 GIF 来自真实录屏，展示胶片拖动过程与选中状态变化。

来自 Project Knowledge Navigator 的胶片交互实现，已抽离宿主项目模型依赖。可连续像素级拖动浏览整组图片；视口裁切与边框分层绘制，拖动时边框不会被裁掉。支持选中回调，宿主项目可据此同步预览内容。

- 连续像素位移，不按帧跳动；胶片本身就是 scrubber，不需要额外滑块或前后按钮。
- 按可视区域渲染少量缩略图，支持长列表。
- 边框在裁切之后绘制，保持完整清晰。
- 使用组件自有的 `FilmstripItem`，不依赖原项目 `NodeContent`。
- 支持辅助功能标签和拖动选中回调。

## 安装

在 Xcode 的 **File → Add Package Dependencies…** 中输入：

`https://github.com/isayaGIT/cross-project-components.git`

或在 `Package.swift` 中添加：

```swift
.package(url: "https://github.com/isayaGIT/cross-project-components.git", from: "1.0.0")
```

## 使用

```swift
import CrossProjectComponents

let filmstripItems = imageURLs.enumerated().map { index, url in
    FilmstripItem(id: url.absoluteString, title: "Image \(index + 1)", imageURL: url)
}

FilmstripScrubber(items: filmstripItems) { item, index in
    // 在这里同步宿主应用的当前图片或预览内容。
}
.frame(height: 48)
```

要求 macOS 13+、Swift 5.9+。无法读取的图片会显示占位缩略图。

## 开发与测试

```sh
swift test
```

## 原则

只提取可复用组件和必要测试；不复制原项目的业务模型、数据存储、应用界面或无关资源。
