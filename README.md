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

A lightweight macOS in-app browser backed by Apple's `WKWebView` (WebKit). It is opt-in: presenting this component does not change link handling elsewhere in the host app.

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
