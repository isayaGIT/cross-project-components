# Cross-Project Components

## TreeView

![TreeView](Components/TreeView/demo.gif)

## FilmstripScrubber

![FilmstripScrubber](Components/FilmstripScrubber/demo.gif)

## MessageComposer

![MessageComposer](Components/MessageComposer/demo.gif)

## SwipeBack

![SwipeBack](Components/SwipeBack/demo.gif)

## EmbeddedBrowser

A lightweight macOS in-app browser backed by Apple's `WKWebView` (WebKit). It is opt-in: presenting this component does not change link handling elsewhere in the host app. Pass a stable, unique `cacheKey` to retain live page state (DOM, scroll position, navigation history, and JavaScript state) while the view is temporarily removed. Up to six inactive pages are retained per app process; this is not an offline snapshot cache, and pages still need to load when the app launches again.

```swift
import CrossProjectComponents
import SwiftUI

struct LinkPreview: View {
    @State private var pageURL = URL(string: "https://example.com")!

    var body: some View {
        EmbeddedBrowserView(
            url: $pageURL,
            configuration: .init(
                showsNavigationControls: true,
                showsAddressField: true
            ),
            // Optional: preserve this page when the browser view is recreated.
            // Use a stable, unique value for each independently retained page.
            cacheKey: "example-com",
            onNavigationRequest: { requestedURL in
                // HTTP(S) is allowed by default. Keep non-web schemes blocked
                // unless the host explicitly chooses to allow them.
                let scheme = requestedURL.scheme?.lowercased()
                return (scheme == "http" || scheme == "https") ? .allow : .cancel
            },
            onURLChange: { currentURL in
                print("Browser URL:", currentURL)
            },
            onLoadingChange: { isLoading in
                print("Browser loading:", isLoading)
            },
            onNavigationFailure: { error in
                print("Browser navigation failed:", error)
            }
        )
    }
}
```

- Change the bound `URL` to navigate the embedded view from host UI.
- The optional address field accepts web URLs; a missing scheme is treated as `https://`.
- HTTP(S) navigation is allowed by default. Non-web schemes such as `mailto:` are cancelled unless `onNavigationRequest` explicitly returns `.allow`; the host can handle those requests separately.
- `onNavigationFailure` receives WebKit navigation errors, allowing the host to display its own error state.
- Links using `target="_blank"` are routed into the same web view rather than creating an unmanaged browser window.
- Website data uses WebKit's default persistent store. It does not guarantee shared cookies or login state with Safari.
- This component does not provide tabs, bookmarks, extension support, a download manager, or full Safari parity. The host app decides where to present it and which URLs to trust.

Build the package with `swift build` from the repository root.

## VideoPlayerView

A lightweight SwiftUI video player backed by Apple's AVKit and AVFoundation. It adds no third-party playback-engine dependency.

- Component API and usage: Components/VideoPlayer/README.md
- Accepts local file URLs, direct HTTP(S) media URLs, and system-compatible HLS playlists.
- Native controls and full-screen playback; playback pauses when the component disappears.
- Open-source design reference: SwiftPlayer (MIT); no source files copied.

## MarkdownPreview

A reusable, read-only SwiftUI view for rendering GitHub-Flavored Markdown.

- [Component API and usage](Components/MarkdownPreview/README.md)
- Supports headings, tables, task lists, fenced code, images, links, blockquotes, and lists.
- Powered by [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui), an MIT-licensed open-source renderer.
